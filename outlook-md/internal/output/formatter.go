package output

import (
	"encoding/json"
	"io"

	"github.com/obsidian-outlook-sync/outlook-md/pkg/schema"
)

// FormatJSON serializes CLIOutput to JSON and writes to the provided writer
func FormatJSON(output *schema.CLIOutput, w io.Writer) error {
	encoder := json.NewEncoder(w)
	encoder.SetIndent("", "  ") // Pretty-print with 2-space indentation

	if err := encoder.Encode(output); err != nil {
		return err
	}

	return nil
}
