#!/bin/bash
set -e

cd /build

# 1. Create flex.go with FlexContent type (full imports)
cat > /build/flex.go << 'GOEOF'
package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"strings"
)

// Avoid unused import errors
var _ = bytes.TrimSpace
var _ = strings.Builder{}
var _ = fmt.Errorf

type FlexContent struct {
	Text string
}

func (fc *FlexContent) UnmarshalJSON(data []byte) error {
	data = bytes.TrimSpace(data)
	if len(data) == 0 {
		return nil
	}
	if data[0] == '"' {
		return json.Unmarshal(data, &fc.Text)
	}
	if data[0] == '[' {
		var parts []struct {
			Type string `json:"type"`
			Text string `json:"text"`
		}
		if err := json.Unmarshal(data, &parts); err != nil {
			return err
		}
		var sb strings.Builder
		for _, p := range parts {
			if p.Type == "text" || p.Type == "" {
				sb.WriteString(p.Text)
			}
		}
		fc.Text = sb.String()
		return nil
	}
	return fmt.Errorf("unsupported content format")
}

func (fc FlexContent) MarshalJSON() ([]byte, error) {
	return json.Marshal(fc.Text)
}
GOEOF

# 2. Change Content type in Message struct
sed -i 's/Content string `json:"content"`/Content FlexContent `json:"content"`/' main.go

# 3. Fix all msg.Content references -> msg.Content.Text
sed -i 's/msg\.Content)/msg.Content.Text)/g' main.go
sed -i 's/msg\.Content,/msg.Content.Text,/g' main.go
sed -i 's/len(msg\.Content)/len(msg.Content.Text)/g' main.go

# 4. Fix response assignment in ChatResponse (string -> FlexContent)
sed -i 's/Content: response,/Content: FlexContent{Text: response},/' main.go

echo "Patch applied successfully"
