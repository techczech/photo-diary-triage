from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
QA = ROOT / "design-qa"
REFERENCES = ROOT / "references"


def comparison(reference_name: str, implementation_name: str, output_name: str) -> None:
    panels = []
    for label, path in (
        ("REFERENCE", REFERENCES / reference_name),
        ("IMPLEMENTATION", QA / implementation_name),
    ):
        image = Image.open(path).convert("RGB")
        image.thumbnail((700, 920), Image.Resampling.LANCZOS)
        panels.append((label, image))

    canvas = Image.new("RGB", (1440, 1024), "white")
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.load_default(size=18)

    for index, (label, image) in enumerate(panels):
        left = 10 + index * 715
        top = 50 + (920 - image.height) // 2
        draw.text((left, 16), label, fill="#111111", font=font)
        canvas.paste(image, (left, top))

    canvas.save(QA / output_name, quality=92)


comparison(
    "timeline-reference.png",
    "timeline-1440x1024.png",
    "timeline-comparison.png",
)
comparison(
    "contact-sheet-reference.png",
    "contact-sheet-1440x1024.png",
    "contact-sheet-comparison.png",
)
