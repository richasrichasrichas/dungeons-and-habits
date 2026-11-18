package domain

import (
	"errors"
	"time"

	"github.com/google/uuid"
)

var (
	ErrNotFound          = errors.New("resource not found")
	ErrConflict          = errors.New("resource already exists")
	ErrQuestUnavailable  = errors.New("quest is not pending")
	ErrInsufficientCoins = errors.New("insufficient coins")
	ErrInvalidInput      = errors.New("invalid input")
)

type Role string

const (
	RoleUser  Role = "user"
	RoleAdmin Role = "admin"
)

type Axis string

const (
	AxisFinanceiro Axis = "financeiro"
	AxisSaude      Axis = "saude"
	AxisPaixoes    Axis = "paixoes"
)

func (a Axis) Valid() bool {
	switch a {
	case AxisFinanceiro, AxisSaude, AxisPaixoes:
		return true
	default:
		return false
	}
}

type Subaxis string

const (
	SubaxisTrabalho   Subaxis = "trabalho"
	SubaxisEstudos    Subaxis = "estudos"
	SubaxisMetas      Subaxis = "metas"
	SubaxisFisica     Subaxis = "fisica"
	SubaxisMental     Subaxis = "mental"
	SubaxisEspiritual Subaxis = "espiritual"
	SubaxisMateriais  Subaxis = "materiais"
	SubaxisCriativas  Subaxis = "criativas"
	SubaxisLazer      Subaxis = "lazer"
)

func (s Subaxis) Axis() Axis {
	switch s {
	case SubaxisTrabalho, SubaxisEstudos, SubaxisMetas:
		return AxisFinanceiro
	case SubaxisFisica, SubaxisMental, SubaxisEspiritual:
		return AxisSaude
	case SubaxisMateriais, SubaxisCriativas, SubaxisLazer:
		return AxisPaixoes
	default:
		return ""
	}
}

func (s Subaxis) Valid() bool { return s.Axis() != "" }

type AbilityKey string

const (
	AbilitySTR AbilityKey = "str"
	AbilityDEX AbilityKey = "dex"
	AbilityCON AbilityKey = "con"
	AbilityINT AbilityKey = "int"
	AbilityWIS AbilityKey = "wis"
	AbilityCHA AbilityKey = "cha"
)

func (a AbilityKey) Valid() bool {
	switch a {
	case AbilitySTR, AbilityDEX, AbilityCON, AbilityINT, AbilityWIS, AbilityCHA:
		return true
	default:
		return false
	}
}

type Difficulty string

const (
	DifficultyEasy   Difficulty = "easy"
	DifficultyMedium Difficulty = "medium"
	DifficultyHard   Difficulty = "hard"
	DifficultyEpic   Difficulty = "epic"
)

func (d Difficulty) Valid() bool {
	switch d {
	case DifficultyEasy, DifficultyMedium, DifficultyHard, DifficultyEpic:
		return true
	default:
		return false
	}
}

func (d Difficulty) Rewards() (xp, coins int) {
	switch d {
	case DifficultyEasy:
		return 10, 5
	case DifficultyMedium:
		return 25, 12
	case DifficultyHard:
		return 50, 25
	case DifficultyEpic:
		return 100, 50
	default:
		return 0, 0
	}
}

type QuestKind string

const (
	QuestMonsterHunt QuestKind = "monster_hunt"
	QuestQuestline   QuestKind = "questline"
)

func (k QuestKind) Valid() bool {
	return k == QuestMonsterHunt || k == QuestQuestline
}

type RewardKind string

const (
	RewardEquipment   RewardKind = "equipamento"
	RewardRest        RewardKind = "descanso"
	RewardConsumable  RewardKind = "consumivel"
	RewardCollectible RewardKind = "colecionavel"
)

func (k RewardKind) Valid() bool {
	switch k {
	case RewardEquipment, RewardRest, RewardConsumable, RewardCollectible:
		return true
	default:
		return false
	}
}

type AbilityScores struct {
	STR int `json:"str"`
	DEX int `json:"dex"`
	CON int `json:"con"`
	INT int `json:"int"`
	WIS int `json:"wis"`
	CHA int `json:"cha"`
}

type AxisProgress struct {
	Axis      Axis    `json:"eixo"`
	Subaxis   Subaxis `json:"subeixo"`
	Level     int     `json:"level"`
	XPCurrent int     `json:"xp_atual"`
	XPTotal   int     `json:"xp_total"`
}

type User struct {
	ID         uuid.UUID     `json:"id"`
	Username   string        `json:"username"`
	XPCurrent  int           `json:"xp_atual"`
	XPTotal    int           `json:"xp_total"`
	Level      int           `json:"level"`
	Coins      int           `json:"moedas"`
	Role       Role          `json:"role"`
	Attributes AbilityScores `json:"atributos_5e"`
}

type UserSheet struct {
	User
	Axes []AxisProgress `json:"eixos"`
}

type Quest struct {
	ID          uuid.UUID  `json:"id"`
	UserID      uuid.UUID  `json:"user_id"`
	Title       string     `json:"titulo"`
	Description string     `json:"descricao"`
	Difficulty  Difficulty `json:"dificuldade"`
	Status      string     `json:"status"`
	Kind        QuestKind  `json:"tipo"`
	Axis        Axis       `json:"eixo_categoria"`
	Subaxis     Subaxis    `json:"subeixo"`
	Ability     AbilityKey `json:"atributo"`
	IsDaily     bool       `json:"is_daily"`
	DueAt       *time.Time `json:"due_at,omitempty"`
	CreatedAt   time.Time  `json:"created_at"`
	CompletedAt *time.Time `json:"completed_at,omitempty"`
}

type QuestInput struct {
	UserID      uuid.UUID
	Title       string
	Description string
	Difficulty  Difficulty
	Kind        QuestKind
	Axis        Axis
	Subaxis     Subaxis
	Ability     AbilityKey
	IsDaily     bool
	DueAt       *time.Time
}

type Reward struct {
	ID          uuid.UUID  `json:"id"`
	UserID      uuid.UUID  `json:"user_id"`
	Title       string     `json:"titulo"`
	Description string     `json:"descricao"`
	Cost        int        `json:"custo_moedas"`
	Kind        RewardKind `json:"tipo"`
	StatKey     string     `json:"stat_key,omitempty"`
	StatBonus   int        `json:"stat_bonus"`
	CreatedAt   time.Time  `json:"created_at"`
}

type RewardInput struct {
	UserID      uuid.UUID
	Title       string
	Description string
	Cost        int
	Kind        RewardKind
	StatKey     AbilityKey
	StatBonus   int
}

type CompletionResult struct {
	QuestID      uuid.UUID     `json:"quest_id"`
	XPReward     int           `json:"xp_ganho"`
	CoinsReward  int           `json:"moedas_ganhas"`
	XPCurrent    int           `json:"xp_atual"`
	XPTotal      int           `json:"xp_total"`
	Coins        int           `json:"moedas"`
	Level        int           `json:"level"`
	Attributes   AbilityScores `json:"atributos_5e"`
	AxisProgress AxisProgress  `json:"progresso_eixo"`
}

type PurchaseResult struct {
	RewardID  uuid.UUID `json:"reward_id"`
	Coins     int       `json:"moedas_restantes"`
	Quantity  int       `json:"quantidade_no_inventario"`
	StatKey   string    `json:"stat_key,omitempty"`
	StatBonus int       `json:"stat_bonus_aplicado"`
}
