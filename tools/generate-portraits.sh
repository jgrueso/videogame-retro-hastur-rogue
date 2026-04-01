#!/bin/bash
# Genera los retratos de personajes para CharacterSelect
# Requiere: deno instalado y FAL_KEY configurado

SKILL_DIR="/Users/jefersongrueso/checkmate-rogue/.claude/skills/godot-asset-generator"
TOOLS_DIR="/Users/jefersongrueso/checkmate-rogue/tools"
OUTPUT_DIR="/Users/jefersongrueso/checkmate-rogue/assets/characters"

echo "=== Checkmate Rogue — Generación de Retratos ==="
echo ""

# Verificaciones previas
if [ -z "$FAL_KEY" ]; then
  echo "ERROR: FAL_KEY no está configurado."
  echo "Ejecuta: export FAL_KEY='tu-api-key'"
  exit 1
fi

if ! command -v deno &> /dev/null; then
  echo "ERROR: Deno no está instalado."
  echo "Instala con: curl -fsSL https://deno.land/install.sh | sh"
  exit 1
fi

echo "1/3 — Generando retratos con fal.ai (Flux Schnell)..."
deno run \
  --allow-env \
  --allow-net \
  --allow-read \
  --allow-write \
  "$SKILL_DIR/scripts/batch-generate.ts" \
  --spec "$TOOLS_DIR/character-portraits-batch.json" \
  --output "$OUTPUT_DIR/raw/" \
  --concurrency 1 \
  --delay 1500

echo ""
echo "2/3 — Procesando sprites (recorte y resize a 180x180)..."
for f in "$OUTPUT_DIR/raw/"*.png; do
  name=$(basename "$f")
  echo "  Procesando $name..."
  deno run \
    --allow-read \
    --allow-write \
    "$SKILL_DIR/scripts/process-sprite.ts" \
    --input "$f" \
    --output "$OUTPUT_DIR/$name" \
    --resize 180x180 \
    --filter linear
done

echo ""
echo "3/3 — Generando archivos .import para Godot..."
deno run \
  --allow-read \
  --allow-write \
  "$SKILL_DIR/scripts/generate-import-files.ts" \
  --input "$OUTPUT_DIR" \
  --preset hd-sprite

echo ""
echo "=== Listo! Retratos guardados en: $OUTPUT_DIR ==="
echo "Archivos generados:"
ls "$OUTPUT_DIR"/*.png 2>/dev/null | xargs -I{} basename {}
