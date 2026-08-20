package mailer

import (
	"fmt"
	"net"
	"net/smtp"
	"os"
	"strings"
)

func Configured() bool {
	return strings.TrimSpace(os.Getenv("SMTP_USER")) != "" && smtpPassword() != ""
}

func smtpPassword() string {
	p := os.Getenv("SMTP_PASSWORD")
	if p == "" {
		p = os.Getenv("SMTP_PASS")
	}
	return strings.ReplaceAll(strings.TrimSpace(p), " ", "")
}

func getenv(key, fallback string) string {
	v := strings.TrimSpace(os.Getenv(key))
	if v == "" {
		return fallback
	}
	return v
}

// Send delivers a plain-text email through SMTP (Gmail app password on port 587).
func Send(to, subject, body string) error {
	host := getenv("SMTP_HOST", "smtp.gmail.com")
	port := getenv("SMTP_PORT", "587")
	user := strings.TrimSpace(os.Getenv("SMTP_USER"))
	pass := smtpPassword()
	from := strings.TrimSpace(os.Getenv("SMTP_FROM"))
	if from == "" {
		from = user
	}
	fromName := getenv("SMTP_FROM_NAME", "Agraz")
	if user == "" || pass == "" {
		return fmt.Errorf("SMTP is not configured")
	}
	to = strings.TrimSpace(to)
	if to == "" {
		return fmt.Errorf("recipient is required")
	}

	fromHeader := fmt.Sprintf("%s <%s>", fromName, from)
	msg := strings.Join([]string{
		"From: " + fromHeader,
		"To: " + to,
		"Subject: " + subject,
		"MIME-Version: 1.0",
		"Content-Type: text/plain; charset=UTF-8",
		"",
		body,
	}, "\r\n")

	addr := net.JoinHostPort(host, port)
	auth := smtp.PlainAuth("", user, pass, host)
	return smtp.SendMail(addr, auth, from, []string{to}, []byte(msg))
}
