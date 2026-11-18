package httpapi

import (
	"context"

	"github.com/example/dungeons-and-habits-api/internal/domain"
	"github.com/google/uuid"
)

// Store is the boundary between HTTP handlers and PostgreSQL.
type Store interface {
	CreateUser(context.Context, string) (domain.UserSheet, error)
	GetUserSheet(context.Context, uuid.UUID) (domain.UserSheet, error)
	ListPendingQuests(context.Context, uuid.UUID) ([]domain.Quest, error)
	CreateQuest(context.Context, domain.QuestInput) (domain.Quest, error)
	CompleteQuest(context.Context, uuid.UUID) (domain.CompletionResult, error)
	ListRewards(context.Context, uuid.UUID) ([]domain.Reward, error)
	CreateReward(context.Context, domain.RewardInput) (domain.Reward, error)
	BuyReward(context.Context, uuid.UUID, uuid.UUID) (domain.PurchaseResult, error)
}
