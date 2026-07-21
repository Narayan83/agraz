package initializers

import (
	"log"

	"github.com/joho/godotenv"
)

func LoadEnviromentVariables() {
	if err := godotenv.Load(); err != nil {
		log.Println("No .env file; using process environment variables")
	}
}
