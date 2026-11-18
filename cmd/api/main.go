package main

import (
	"context"
	"log"
	"os"
	"strconv"
	"time"

	"github.com/example/dungeons-and-habits-api/internal/httpapi"
	"github.com/example/dungeons-and-habits-api/internal/repository"
	"github.com/gofiber/fiber/v3"
	"github.com/gofiber/fiber/v3/middleware/recover"
	"github.com/jackc/pgx/v5/pgxpool"
)

func main() {
	databaseURL := os.Getenv("DATABASE_URL")
	if databaseURL == "" {
		log.Fatal("DATABASE_URL is required")
	}

	poolConfig, err := pgxpool.ParseConfig(databaseURL)
	if err != nil {
		log.Fatalf("parse DATABASE_URL: %v", err)
	}
	maxConns := envInt("DB_MAX_CONNS", 20)
	minConns := envInt("DB_MIN_CONNS", 1)
	if maxConns == 0 || minConns > maxConns {
		log.Fatal("DB_MAX_CONNS must be positive and DB_MIN_CONNS cannot exceed it")
	}
	poolConfig.MaxConns = int32(maxConns)
	poolConfig.MinConns = int32(minConns)
	poolConfig.MaxConnLifetime = 30 * time.Minute
	poolConfig.MaxConnIdleTime = 5 * time.Minute

	startupCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	pool, err := pgxpool.NewWithConfig(startupCtx, poolConfig)
	if err != nil {
		log.Fatalf("create PostgreSQL pool: %v", err)
	}
	defer pool.Close()
	if err := pool.Ping(startupCtx); err != nil {
		log.Fatalf("connect to PostgreSQL: %v", err)
	}

	app := fiber.New(fiber.Config{
		BodyLimit: 1 << 20, // 1 MiB request bodies
	})
	app.Use(recover.New())

	store := repository.NewPostgres(pool)
	httpapi.RegisterRoutes(app, httpapi.NewHandlers(store))

	port := os.Getenv("PORT")
	if port == "" {
		port = "8080"
	}
	if _, err := strconv.Atoi(port); err != nil {
		log.Fatalf("PORT must be numeric: %v", err)
	}

	log.Printf("Dungeons and Habits API listening on :%s", port)
	if err := app.Listen(":" + port); err != nil {
		log.Fatalf("Fiber server stopped: %v", err)
	}
}

func envInt(key string, fallback int) int {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	number, err := strconv.Atoi(value)
	if err != nil || number < 0 {
		log.Fatalf("%s must be a non-negative integer", key)
	}
	return number
}
