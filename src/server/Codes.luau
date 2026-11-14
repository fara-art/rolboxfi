-- Redeemable codes. Server-only, so nobody can read them out of the client.
-- Keys are UPPERCASE. Optional: expires = unix time after which the code stops working.
return {
	STARRNG = { cash = 5000, boostLuck = 15 },
	RELEASE = { item = "sun|shiny", count = 2 },
	SPACE = { item = "giant", count = 1, boostSpeed = 15 },
}
