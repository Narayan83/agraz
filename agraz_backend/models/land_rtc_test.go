package models

import "testing"

func TestComputeTotalAcres(t *testing.T) {
	cases := []struct {
		acre, gunta, ana int
		want             string
	}{
		{1, 0, 0, "1"},
		{0, 40, 0, "1"},
		{0, 0, 4, "0.025"}, // 4 ana = 1 gunta = 1/40 acre
		{0, 1, 0, "0.025"},
		{2, 20, 2, "2.5125"},
	}
	for _, c := range cases {
		got := ComputeTotalAcres(c.acre, c.gunta, c.ana)
		if got.String() != c.want {
			t.Fatalf("ComputeTotalAcres(%d,%d,%d)=%s want %s", c.acre, c.gunta, c.ana, got.String(), c.want)
		}
	}
}
