package repository

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/example/dungeons-and-habits-api/internal/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
)

const userColumns = `id, username, xp_atual, xp_total, level, moedas, role,
                     str, dex, con, "int", wis, cha`

type Postgres struct {
	pool *pgxpool.Pool
}

func NewPostgres(pool *pgxpool.Pool) *Postgres {
	return &Postgres{pool: pool}
}

func (p *Postgres) CreateUser(ctx context.Context, username string) (domain.UserSheet, error) {
	id := uuid.New()
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return domain.UserSheet{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	user, err := scanUserSheet(tx.QueryRow(ctx, `
		INSERT INTO users (id, username)
		VALUES ($1, $2)
		RETURNING `+userColumns,
		id, username,
	))
	if err != nil {
		return domain.UserSheet{}, translateDBError(err)
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO user_axis_progress (user_id, axis_category, subaxis)
		VALUES
			($1, 'financeiro', 'trabalho'),
			($1, 'financeiro', 'estudos'),
			($1, 'financeiro', 'metas'),
			($1, 'saude', 'fisica'),
			($1, 'saude', 'mental'),
			($1, 'saude', 'espiritual'),
			($1, 'paixoes', 'materiais'),
			($1, 'paixoes', 'criativas'),
			($1, 'paixoes', 'lazer')`, id)
	if err != nil {
		return domain.UserSheet{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.UserSheet{}, err
	}

	user.Axes = initialAxes()
	return user, nil
}

func (p *Postgres) GetUserSheet(ctx context.Context, id uuid.UUID) (domain.UserSheet, error) {
	user, err := scanUserSheet(p.pool.QueryRow(ctx,
		`SELECT `+userColumns+` FROM users WHERE id = $1`, id))
	if err != nil {
		return domain.UserSheet{}, translateDBError(err)
	}

	rows, err := p.pool.Query(ctx, `
		SELECT axis_category, subaxis, level, xp_atual, xp_total
		FROM user_axis_progress
		WHERE user_id = $1
		ORDER BY axis_category, subaxis`, id)
	if err != nil {
		return domain.UserSheet{}, err
	}
	defer rows.Close()

	user.Axes = make([]domain.AxisProgress, 0, 9)
	for rows.Next() {
		var progress domain.AxisProgress
		if err := rows.Scan(
			&progress.Axis,
			&progress.Subaxis,
			&progress.Level,
			&progress.XPCurrent,
			&progress.XPTotal,
		); err != nil {
			return domain.UserSheet{}, err
		}
		user.Axes = append(user.Axes, progress)
	}
	if err := rows.Err(); err != nil {
		return domain.UserSheet{}, err
	}
	return user, nil
}

func (p *Postgres) ListPendingQuests(ctx context.Context, userID uuid.UUID) ([]domain.Quest, error) {
	rows, err := p.pool.Query(ctx, `
		SELECT id, user_id, titulo, descricao, dificuldade,
		       CASE
		           WHEN is_daily AND completed_at <
		               (date_trunc('day', now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC')
		           THEN 'pending'
	           ELSE status
	       END AS status,
	       tipo,
		       eixo_categoria, subeixo, atributo, is_daily, due_at, created_at, completed_at
		FROM quests
		WHERE user_id = $1 AND (
			status = 'pending' OR
			(is_daily AND completed_at <
				(date_trunc('day', now() AT TIME ZONE 'UTC') AT TIME ZONE 'UTC'))
		)
		ORDER BY due_at NULLS LAST, created_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	quests := make([]domain.Quest, 0)
	for rows.Next() {
		quest, err := scanQuest(rows)
		if err != nil {
			return nil, err
		}
		quests = append(quests, quest)
	}
	return quests, rows.Err()
}

func (p *Postgres) CreateQuest(ctx context.Context, input domain.QuestInput) (domain.Quest, error) {
	quest := domain.Quest{
		ID:          uuid.New(),
		UserID:      input.UserID,
		Title:       input.Title,
		Description: input.Description,
		Difficulty:  input.Difficulty,
		Status:      "pending",
		Kind:        input.Kind,
		Axis:        input.Axis,
		Subaxis:     input.Subaxis,
		Ability:     input.Ability,
		IsDaily:     input.IsDaily,
		DueAt:       input.DueAt,
	}
	err := p.pool.QueryRow(ctx, `
		INSERT INTO quests (
			id, user_id, titulo, descricao, dificuldade, tipo,
			eixo_categoria, subeixo, atributo, is_daily, due_at
		)
		SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11
		WHERE EXISTS (SELECT 1 FROM users WHERE id = $2)
		RETURNING created_at`,
		quest.ID, quest.UserID, quest.Title, quest.Description,
		quest.Difficulty, quest.Kind, quest.Axis, quest.Subaxis, quest.Ability,
		quest.IsDaily, quest.DueAt,
	).Scan(&quest.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.Quest{}, domain.ErrNotFound
	}
	if err != nil {
		return domain.Quest{}, translateDBError(err)
	}
	return quest, nil
}

func (p *Postgres) CompleteQuest(ctx context.Context, questID uuid.UUID) (domain.CompletionResult, error) {
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return domain.CompletionResult{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var userID uuid.UUID
	var status string
	var isDaily bool
	var completedAt pgtype.Timestamptz
	var difficulty domain.Difficulty
	var axis domain.Axis
	var subaxis domain.Subaxis
	var ability domain.AbilityKey
	err = tx.QueryRow(ctx, `
		SELECT user_id, status, is_daily, completed_at,
		       dificuldade, eixo_categoria, subeixo, atributo
		FROM quests
		WHERE id = $1
		FOR UPDATE`, questID,
	).Scan(&userID, &status, &isDaily, &completedAt, &difficulty, &axis, &subaxis, &ability)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.CompletionResult{}, domain.ErrNotFound
	}
	if err != nil {
		return domain.CompletionResult{}, err
	}
	if status != "pending" {
		utcDayStart := time.Now().UTC().Truncate(24 * time.Hour)
		canRepeatToday := isDaily && completedAt.Valid && completedAt.Time.Before(utcDayStart)
		if !canRepeatToday {
			return domain.CompletionResult{}, domain.ErrQuestUnavailable
		}
	}

	xpReward, coinReward := difficulty.Rewards()
	if xpReward == 0 {
		return domain.CompletionResult{}, domain.ErrInvalidInput
	}

	var level, xpCurrent int
	err = tx.QueryRow(ctx,
		`SELECT level, xp_atual FROM users WHERE id = $1 FOR UPDATE`, userID,
	).Scan(&level, &xpCurrent)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.CompletionResult{}, domain.ErrNotFound
	}
	if err != nil {
		return domain.CompletionResult{}, err
	}

	xpCurrent += xpReward
	for xpCurrent >= 100*level {
		xpCurrent -= 100 * level
		level++
	}

	statColumn, statXPColumn, ok := abilityColumns(ability)
	if !ok {
		return domain.CompletionResult{}, domain.ErrInvalidInput
	}
	updateUserSQL := fmt.Sprintf(`
		UPDATE users
		SET level = $2,
		    xp_atual = $3,
		    xp_total = xp_total + $4,
		    moedas = moedas + $5,
		    %s = LEAST(30, %s + ((%s + $6) / 100)),
		    %s = (%s + $6) %% 100
		WHERE id = $1
		RETURNING level, xp_atual, xp_total, moedas, str, dex, con, "int", wis, cha`,
		statColumn, statColumn, statXPColumn, statXPColumn, statXPColumn,
	)
	var result domain.CompletionResult
	result.QuestID = questID
	result.XPReward = xpReward
	result.CoinsReward = coinReward
	err = tx.QueryRow(ctx, updateUserSQL,
		userID, level, xpCurrent, xpReward, coinReward, xpReward,
	).Scan(
		&result.Level,
		&result.XPCurrent,
		&result.XPTotal,
		&result.Coins,
		&result.Attributes.STR,
		&result.Attributes.DEX,
		&result.Attributes.CON,
		&result.Attributes.INT,
		&result.Attributes.WIS,
		&result.Attributes.CHA,
	)
	if err != nil {
		return domain.CompletionResult{}, err
	}

	_, err = tx.Exec(ctx, `
		UPDATE quests SET status = 'completed', completed_at = now()
		WHERE id = $1`, questID)
	if err != nil {
		return domain.CompletionResult{}, err
	}
	err = tx.QueryRow(ctx, `
		INSERT INTO user_axis_progress (
			user_id, axis_category, subaxis, xp_total, xp_atual, level
		)
		VALUES ($1, $2, $3, $4, $4 % 100, 1 + ($4 / 100))
		ON CONFLICT (user_id, subaxis) DO UPDATE
		SET xp_total = user_axis_progress.xp_total + EXCLUDED.xp_total,
		    xp_atual = (user_axis_progress.xp_atual + EXCLUDED.xp_total) % 100,
		    level = 1 + ((user_axis_progress.xp_total + EXCLUDED.xp_total) / 100)
		RETURNING axis_category, subaxis, level, xp_atual, xp_total`,
		userID, axis, subaxis, xpReward,
	).Scan(
		&result.AxisProgress.Axis,
		&result.AxisProgress.Subaxis,
		&result.AxisProgress.Level,
		&result.AxisProgress.XPCurrent,
		&result.AxisProgress.XPTotal,
	)
	if err != nil {
		return domain.CompletionResult{}, err
	}
	if err := tx.Commit(ctx); err != nil {
		return domain.CompletionResult{}, err
	}
	return result, nil
}

func (p *Postgres) ListRewards(ctx context.Context, userID uuid.UUID) ([]domain.Reward, error) {
	rows, err := p.pool.Query(ctx, `
		SELECT id, user_id, titulo, descricao, custo_moedas, tipo,
		       COALESCE(stat_key, ''), stat_bonus, created_at
		FROM rewards
		WHERE user_id = $1
		ORDER BY created_at DESC`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	rewards := make([]domain.Reward, 0)
	for rows.Next() {
		var reward domain.Reward
		if err := rows.Scan(
			&reward.ID,
			&reward.UserID,
			&reward.Title,
			&reward.Description,
			&reward.Cost,
			&reward.Kind,
			&reward.StatKey,
			&reward.StatBonus,
			&reward.CreatedAt,
		); err != nil {
			return nil, err
		}
		rewards = append(rewards, reward)
	}
	return rewards, rows.Err()
}

func (p *Postgres) CreateReward(ctx context.Context, input domain.RewardInput) (domain.Reward, error) {
	reward := domain.Reward{
		ID:          uuid.New(),
		UserID:      input.UserID,
		Title:       input.Title,
		Description: input.Description,
		Cost:        input.Cost,
		Kind:        input.Kind,
		StatKey:     string(input.StatKey),
		StatBonus:   input.StatBonus,
	}
	err := p.pool.QueryRow(ctx, `
		INSERT INTO rewards (
			id, user_id, titulo, descricao, custo_moedas,
			tipo, stat_key, stat_bonus
		)
		SELECT $1, $2, $3, $4, $5, $6, NULLIF($7, ''), $8
		WHERE EXISTS (SELECT 1 FROM users WHERE id = $2)
		RETURNING created_at`,
		reward.ID, reward.UserID, reward.Title, reward.Description,
		reward.Cost, reward.Kind, reward.StatKey, reward.StatBonus,
	).Scan(&reward.CreatedAt)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.Reward{}, domain.ErrNotFound
	}
	if err != nil {
		return domain.Reward{}, translateDBError(err)
	}
	return reward, nil
}

func (p *Postgres) BuyReward(ctx context.Context, userID, rewardID uuid.UUID) (domain.PurchaseResult, error) {
	tx, err := p.pool.Begin(ctx)
	if err != nil {
		return domain.PurchaseResult{}, err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	var rewardUserID uuid.UUID
	var kind domain.RewardKind
	var cost, statBonus int
	var statKey string
	err = tx.QueryRow(ctx, `
		SELECT user_id, tipo, custo_moedas, COALESCE(stat_key, ''), stat_bonus
		FROM rewards
		WHERE id = $1
		FOR UPDATE`, rewardID,
	).Scan(&rewardUserID, &kind, &cost, &statKey, &statBonus)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.PurchaseResult{}, domain.ErrNotFound
	}
	if err != nil {
		return domain.PurchaseResult{}, err
	}
	if rewardUserID != userID {
		return domain.PurchaseResult{}, domain.ErrNotFound
	}

	var coins int
	err = tx.QueryRow(ctx, `SELECT moedas FROM users WHERE id = $1 FOR UPDATE`, userID).Scan(&coins)
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.PurchaseResult{}, domain.ErrNotFound
	}
	if err != nil {
		return domain.PurchaseResult{}, err
	}
	if coins < cost {
		return domain.PurchaseResult{}, domain.ErrInsufficientCoins
	}
	if err := tx.QueryRow(ctx,
		`UPDATE users SET moedas = moedas - $2 WHERE id = $1 RETURNING moedas`,
		userID, cost,
	).Scan(&coins); err != nil {
		return domain.PurchaseResult{}, err
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO user_inventory (user_id, reward_id, quantity)
		VALUES ($1, $2, 1)
		ON CONFLICT (user_id, reward_id)
		DO UPDATE SET quantity = user_inventory.quantity + 1`, userID, rewardID)
	if err != nil {
		return domain.PurchaseResult{}, err
	}
	var quantity int
	err = tx.QueryRow(ctx, `
		SELECT quantity FROM user_inventory
		WHERE user_id = $1 AND reward_id = $2`, userID, rewardID,
	).Scan(&quantity)
	if err != nil {
		return domain.PurchaseResult{}, err
	}
	_, err = tx.Exec(ctx, `
		INSERT INTO reward_purchases (
			user_id, reward_id, cost_paid, title_snapshot, tipo_snapshot,
			stat_key_snapshot, stat_bonus_snapshot
		)
		SELECT $1, id, $3, titulo, tipo, stat_key, stat_bonus
		FROM rewards WHERE id = $2`, userID, rewardID, cost)
	if err != nil {
		return domain.PurchaseResult{}, err
	}

	if statBonus > 0 && statKey != "" {
		column, _, ok := abilityColumns(domain.AbilityKey(statKey))
		if !ok || kind != domain.RewardEquipment {
			return domain.PurchaseResult{}, domain.ErrInvalidInput
		}
		applyBonusSQL := fmt.Sprintf(
			`UPDATE users SET %s = LEAST(30, %s + $2) WHERE id = $1`,
			column, column,
		)
		if _, err := tx.Exec(ctx, applyBonusSQL, userID, statBonus); err != nil {
			return domain.PurchaseResult{}, err
		}
	}

	if err := tx.Commit(ctx); err != nil {
		return domain.PurchaseResult{}, err
	}
	return domain.PurchaseResult{
		RewardID:  rewardID,
		Coins:     coins,
		Quantity:  quantity,
		StatKey:   statKey,
		StatBonus: statBonus,
	}, nil
}

func scanUserSheet(row pgx.Row) (domain.UserSheet, error) {
	var user domain.UserSheet
	err := row.Scan(
		&user.ID,
		&user.Username,
		&user.XPCurrent,
		&user.XPTotal,
		&user.Level,
		&user.Coins,
		&user.Role,
		&user.Attributes.STR,
		&user.Attributes.DEX,
		&user.Attributes.CON,
		&user.Attributes.INT,
		&user.Attributes.WIS,
		&user.Attributes.CHA,
	)
	if err != nil {
		return domain.UserSheet{}, translateDBError(err)
	}
	return user, nil
}

func scanQuest(row interface{ Scan(...any) error }) (domain.Quest, error) {
	var quest domain.Quest
	var dueAt, completedAt pgtype.Timestamptz
	err := row.Scan(
		&quest.ID,
		&quest.UserID,
		&quest.Title,
		&quest.Description,
		&quest.Difficulty,
		&quest.Status,
		&quest.Kind,
		&quest.Axis,
		&quest.Subaxis,
		&quest.Ability,
		&quest.IsDaily,
		&dueAt,
		&quest.CreatedAt,
		&completedAt,
	)
	if err != nil {
		return domain.Quest{}, err
	}
	if dueAt.Valid {
		quest.DueAt = &dueAt.Time
	}
	if completedAt.Valid {
		quest.CompletedAt = &completedAt.Time
	}
	return quest, nil
}

func initialAxes() []domain.AxisProgress {
	subaxes := []domain.Subaxis{
		domain.SubaxisTrabalho, domain.SubaxisEstudos, domain.SubaxisMetas,
		domain.SubaxisFisica, domain.SubaxisMental, domain.SubaxisEspiritual,
		domain.SubaxisMateriais, domain.SubaxisCriativas, domain.SubaxisLazer,
	}
	axes := make([]domain.AxisProgress, 0, len(subaxes))
	for _, subaxis := range subaxes {
		axes = append(axes, domain.AxisProgress{Axis: subaxis.Axis(), Subaxis: subaxis, Level: 1})
	}
	return axes
}

func abilityColumns(key domain.AbilityKey) (statColumn, xpColumn string, ok bool) {
	switch key {
	case domain.AbilitySTR:
		return "str", "str_xp", true
	case domain.AbilityDEX:
		return "dex", "dex_xp", true
	case domain.AbilityCON:
		return "con", "con_xp", true
	case domain.AbilityINT:
		return `"int"`, "int_xp", true
	case domain.AbilityWIS:
		return "wis", "wis_xp", true
	case domain.AbilityCHA:
		return "cha", "cha_xp", true
	default:
		return "", "", false
	}
}

func translateDBError(err error) error {
	if errors.Is(err, pgx.ErrNoRows) {
		return domain.ErrNotFound
	}
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		switch pgErr.Code {
		case "23505": // unique_violation
			return domain.ErrConflict
		case "23503", "23514", "22P02": // foreign key, check, invalid enum/UUID
			return domain.ErrInvalidInput
		}
	}
	return err
}
