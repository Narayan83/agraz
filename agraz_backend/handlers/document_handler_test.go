package handler

import (
	"testing"

	"gorm.io/datatypes"
)

func TestSanitizeImageURLs(t *testing.T) {
	got := sanitizeImageURLs([]string{
		" /uploads/documents/a.jpg ",
		"",
		"/uploads/documents/a.jpg",
		"/uploads/documents/b.png",
	})
	if len(got) != 2 {
		t.Fatalf("got %v", got)
	}
	if got[0] != "/uploads/documents/a.jpg" || got[1] != "/uploads/documents/b.png" {
		t.Fatalf("unexpected order: %v", got)
	}
}

func TestParseImageURLList(t *testing.T) {
	raw := datatypes.JSON([]byte(`["/uploads/documents/x.jpg"," "]`))
	got := parseImageURLList(raw)
	if len(got) != 1 || got[0] != "/uploads/documents/x.jpg" {
		t.Fatalf("got %v", got)
	}
	if len(parseImageURLList(nil)) != 0 {
		t.Fatal("nil should be empty")
	}
}

func TestFolderAndDocumentNameValid(t *testing.T) {
	if _, err := folderNameValid("  "); err == nil {
		t.Fatal("blank folder should fail")
	}
	name, err := folderNameValid("  Ravi  ")
	if err != nil || name != "Ravi" {
		t.Fatalf("got %q %v", name, err)
	}
	if _, err := documentNameValid(""); err == nil {
		t.Fatal("blank document should fail")
	}
	d, err := documentNameValid(" Aadhaar ")
	if err != nil || d != "Aadhaar" {
		t.Fatalf("got %q %v", d, err)
	}
}
