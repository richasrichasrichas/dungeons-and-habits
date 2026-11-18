package httpapi

import (
	"net"
	"net/url"

	"github.com/gofiber/fiber/v3"
)

func RegisterRoutes(app *fiber.App, handlers *Handlers) {
	// The browser prototype is served on localhost during development. Allow only
	// loopback origins so it can call the local API without opening CORS broadly.
	app.Use(func(c fiber.Ctx) error {
		origin := c.Get("Origin")
		if origin != "" {
			parsed, err := url.Parse(origin)
			if err == nil && isLoopbackHost(parsed.Hostname()) {
				c.Set("Access-Control-Allow-Origin", origin)
				c.Set("Vary", "Origin")
				c.Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
				c.Set("Access-Control-Allow-Headers", "Content-Type, Authorization")
			}
		}
		if c.Method() == "OPTIONS" {
			return c.SendStatus(fiber.StatusNoContent)
		}
		return c.Next()
	})

	app.Get("/healthz", func(c fiber.Ctx) error {
		return c.JSON(fiber.Map{"status": "ok"})
	})

	app.Post("/users", handlers.CreateUser)
	app.Get("/user/:id/sheet", handlers.GetUserSheet)

	app.Get("/quests", handlers.ListPendingQuests)
	app.Post("/quests", handlers.CreateQuest)
	app.Post("/quests/:id/complete", handlers.CompleteQuest)

	app.Get("/rewards", handlers.ListRewards)
	app.Post("/rewards", handlers.CreateReward)
	app.Post("/rewards/:id/buy", handlers.BuyReward)
}

func isLoopbackHost(host string) bool {
	if host == "localhost" {
		return true
	}
	ip := net.ParseIP(host)
	return ip != nil && ip.IsLoopback()
}
