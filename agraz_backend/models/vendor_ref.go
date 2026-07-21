package models

// VendorRefJSON is a minimal vendor payload for public product APIs.
type VendorRefJSON struct {
	ID   uint   `json:"id"`
	Name string `json:"name"`
}

// VendorOfferJSON is a vendor selling a catalog product (marketplace).
type VendorOfferJSON struct {
	ID       uint   `json:"id"`
	Name     string `json:"name"`
	Quantity int    `json:"quantity"`
}
