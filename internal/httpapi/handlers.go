package httpapi

import (
	"context"
	"errors"
	"log"
	"regexp"
	"strings"
	"time"

	"github.com/example/dungeons-and-habits-api/internal/domain"
	"github.com/gofiber/fiber/v3"
	"github.com/google/uuid"
)

const databaseTimeout = 4 * time.Second

var usernamePattern = regexp.MustCompile(`^[A-Za-z0-9_]{3,32}$`)

type Handlers struct {
	store Store
}

func NewHandlers(store Store) *Handlers {
	return &Handlers{store: store}
}

type createUserRequest struct {
	Username string `json:"username"`
}

type createQuestRequest struct {
	UserID      uuid.UUID         `json:"user_id"`
	Title       string            `json:"title"`
	Description string            `json:"description"`
	Difficulty  domain.Difficulty `json:"difficulty"`
	Kind        domain.QuestKind  `json:"type"`
	Axis        domain.Axis       `json:"axis_category"`
	Subaxis     domain.Subaxis    `json:"subaxis"`
	Ability     domain.AbilityKey `json:"ability_key"`
	IsDaily     bool              `json:"is_daily"`
	DueAt       *time.Time        `json:"due_at"`
}

type createRewardRequest struct {
	UserID      uuid.UUID         `json:"user_id"`
	Title       string            `json:"title"`
	Description string            `json:"description"`
	Cost        int               `json:"cost"`
	Kind        domain.RewardKind `json:"type"`
	StatKey     domain.AbilityKey `json:"stat_key"`
	StatBonus   int               `json:"stat_bonus"`
}

type buyRewardRequest struct {
	UserID uuid.UUID `json:"user_id"`
}

func (h *Handlers) CreateUser(c fiber.Ctx) error {
	var input createUserRequest
	if err := c.Bind().JSON(&input); err != nil {
		return badRequest(c, "JSON inválido")
	}
	input.Username = strings.TrimSpace(input.Username)
	if !usernamePattern.MatchString(input.Username) {
		return badRequest(c, "username deve ter 3 a 32 caracteres: letras, números ou underscore")
	}

	ctx, cancel := context.WithTimeout(context.Background(), databaseTimeout)
	defer cancel()
	user, err := h.store.CreateUser(ctx, input.Username)
	if err != nil {
		return handleError(c, err)
	}
	return c.Status(fiber.StatusCreated).JSON(user)
}

func (h *Handlers) GetUserSheet(c fiber.Ctx) error {
	id, err := parseID(c.Params("id"))
	if err != nil {
		return badRequest(c, "id deve ser um UUID válido")
	}
	ctx, cancel := context.WithTimeout(context.Background(), databaseTimeout)
	defer cancel()
	sheet, err := h.store.GetUserSheet(ctx, id)
	if err != nil {
		return handleError(c, err)
	}
	return c.JSON(sheet)
}

func (h *Handlers) ListPendingQuests(c fiber.Ctx) error {
	userID, err := parseID(c.Query("user_id"))
	if err != nil {
		return badRequest(c, "informe user_id como UUID na query string")
	}
	ctx, cancel := context.WithTimeout(context.Background(), databaseTimeout)
	defer cancel()
	quests, err := h.store.ListPendingQuests(ctx, userID)
	if err != nil {
		return handleError(c, err)
	}
	return c.JSON(quests)
}

func (h *Handlers) CreateQuest(c fiber.Ctx) error {
	var input createQuestRequest
	if err := c.Bind().JSON(&input); err != nil {
		return badRequest(c, "JSON inválido")
	}
	input.Title = strings.TrimSpace(input.Title)
	input.Description = strings.TrimSpace(input.Description)
	if input.UserID == uuid.Nil || input.Title == "" || len(input.Title) > 160 || len(input.Description) > 2000 {
		return badRequest(c, "user_id, título e descrição são inválidos")
	}
	if !input.Difficulty.Valid() || !input.Kind.Valid() || !input.Axis.Valid() ||
		!input.Subaxis.Valid() || input.Subaxis.Axis() != input.Axis || !input.Ability.Valid() {
		return badRequest(c, "dificuldade, tipo, eixo, subeixo ou atributo inválido")
	}

	ctx, cancel := context.WithTimeout(context.Background(), databaseTimeout)
	defer cancel()
	quest, err := h.store.CreateQuest(ctx, domain.QuestInput{
		UserID:      input.UserID,
		Title:       input.Title,
		Description: input.Description,
		Difficulty:  input.Difficulty,
		Kind:        input.Kind,
		Axis:        input.Axis,
		Subaxis:     input.Subaxis,
		Ability:     input.Ability,
		IsDaily:     input.IsDaily,
		DueAt:       input.DueAt,
	})
	if err != nil {
		return handleError(c, err)
	}
	return c.Status(fiber.StatusCreated).JSON(quest)
}

func (h *Handlers) CompleteQuest(c fiber.Ctx) error {
	id, err := parseID(c.Params("id"))
	if err != nil {
		return badRequest(c, "id deve ser um UUID válido")
	}
	ctx, cancel := context.WithTimeout(context.Background(), databaseTimeout)
	defer cancel()
	result, err := h.store.CompleteQuest(ctx, id)
	if err != nil {
		return handleError(c, err)
	}
	return c.JSON(result)
}

func (h *Handlers) ListRewards(c fiber.Ctx) error {
	userID, err := parseID(c.Query("user_id"))
	if err != nil {
		return badRequest(c, "informe user_id como UUID na query string")
	}
	ctx, cancel := context.WithTimeout(context.Background(), databaseTimeout)
	defer cancel()
	rewards, err := h.store.ListRewards(ctx, userID)
	if err != nil {
		return handleError(c, err)
	}
	return c.JSON(rewards)
}

func (h *Handlers) CreateReward(c fiber.Ctx) error {
	var input createRewardRequest
	if err := c.Bind().JSON(&input); err != nil {
		return badRequest(c, "JSON inválido")
	}
	input.Title = strings.TrimSpace(input.Title)
	input.Description = strings.TrimSpace(input.Description)
	if input.UserID == uuid.Nil || input.Title == "" || len(input.Title) > 160 ||
		len(input.Description) > 2000 || input.Cost < 0 || input.Cost > 1_000_000 {
		return badRequest(c, "user_id, título, descrição ou custo inválido")
	}
	if !input.Kind.Valid() || input.StatBonus < 0 || input.StatBonus > 10 {
		return badRequest(c, "tipo ou stat_bonus inválido")
	}
	if input.StatKey != "" && !input.StatKey.Valid() {
		return badRequest(c, "stat_key deve ser str, dex, con, int, wis ou cha")
	}
	if input.StatBonus > 0 && (input.Kind != domain.RewardEquipment || input.StatKey == "") {
		return badRequest(c, "bônus de atributo exige tipo equipamento e stat_key")
	}

	ctx, cancel := context.WithTimeout(context.Background(), databaseTimeout)
	defer cancel()
	reward, err := h.store.CreateReward(ctx, domain.RewardInput{
		UserID:      input.UserID,
		Title:       input.Title,
		Description: input.Description,
		Cost:        input.Cost,
		Kind:        input.Kind,
		StatKey:     input.StatKey,
		StatBonus:   input.StatBonus,
	})
	if err != nil {
		return handleError(c, err)
	}
	return c.Status(fiber.StatusCreated).JSON(reward)
}

func (h *Handlers) BuyReward(c fiber.Ctx) error {
	rewardID, err := parseID(c.Params("id"))
	if err != nil {
		return badRequest(c, "id deve ser um UUID válido")
	}
	var input buyRewardRequest
	if err := c.Bind().JSON(&input); err != nil || input.UserID == uuid.Nil {
		return badRequest(c, "informe user_id como UUID no corpo JSON")
	}
	ctx, cancel := context.WithTimeout(context.Background(), databaseTimeout)
	defer cancel()
	result, err := h.store.BuyReward(ctx, input.UserID, rewardID)
	if err != nil {
		return handleError(c, err)
	}
	return c.JSON(result)
}

func parseID(value string) (uuid.UUID, error) {
	return uuid.Parse(value)
}

func badRequest(c fiber.Ctx, message string) error {
	return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": message})
}

func handleError(c fiber.Ctx, err error) error {
	switch {
	case errors.Is(err, domain.ErrNotFound):
		return c.Status(fiber.StatusNotFound).JSON(fiber.Map{"error": "recurso não encontrado"})
	case errors.Is(err, domain.ErrConflict):
		return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "recurso já existe"})
	case errors.Is(err, domain.ErrQuestUnavailable):
		return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "quest já concluída ou indisponível"})
	case errors.Is(err, domain.ErrInsufficientCoins):
		return c.Status(fiber.StatusConflict).JSON(fiber.Map{"error": "moedas insuficientes"})
	case errors.Is(err, domain.ErrInvalidInput):
		return c.Status(fiber.StatusBadRequest).JSON(fiber.Map{"error": "dados inválidos"})
	default:
		log.Printf("request failed: %v", err)
		return c.Status(fiber.StatusInternalServerError).JSON(fiber.Map{"error": "erro interno"})
	}
}
