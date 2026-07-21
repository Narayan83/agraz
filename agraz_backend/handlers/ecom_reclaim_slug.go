package handler

import "fmt"

// slugAfterSoftDelete rewrites slug so the original can be reused by a new row
// while the unique index on slug still holds for the soft-deleted record.
func slugAfterSoftDelete(original string, id uint) string {
	suffix := fmt.Sprintf("__d%d", id)
	const limit = 255
	maxBase := limit - len(suffix)
	if maxBase < 1 {
		maxBase = 1
	}
	base := original
	if len(base) > maxBase {
		base = base[:maxBase]
	}
	return base + suffix
}
