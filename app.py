from datetime import datetime
from pathlib import Path
import shutil

import gradio as gr


UPLOAD_ROOT = Path("upload")
OUTPUT_ROOT = Path("output")


def process_file(file_path):
    if not file_path:
        raise gr.Error("Upload a PDF file first.")

    source_path = Path(file_path).resolve()
    if source_path.suffix.lower() != ".pdf":
        raise gr.Error("Please upload a PDF file.")

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S-%f")
    upload_dir = UPLOAD_ROOT / timestamp
    output_dir = OUTPUT_ROOT / timestamp
    upload_dir.mkdir(parents=True, exist_ok=True)
    output_dir.mkdir(parents=True, exist_ok=True)

    uploaded_pdf = upload_dir / source_path.name
    shutil.copyfile(source_path, uploaded_pdf)

    try:
        from extract import MarkdownPDFExtractor
    except ModuleNotFoundError as exc:
        raise gr.Error(
            f"Missing dependency: {exc.name}. Run `python -m pip install -r requirements.txt`."
        ) from exc

    extractor = MarkdownPDFExtractor(str(uploaded_pdf), output_dir=output_dir)
    markdown_content, markdown_pages = extractor.extract()
    if not markdown_content and not markdown_pages:
        raise gr.Error("PDF conversion failed. Check logs/extract.log for details.")

    return shutil.make_archive(str(output_dir), "zip", root_dir=output_dir)


title = "PDF to Markdown"
description = (
    "Upload a PDF and download a zip containing the converted markdown file "
    "and extracted images."
)
article = (
    "The converter preserves text, tables, links, basic formatting, and image "
    "references where extraction is possible."
)


demo = gr.Interface(
    fn=process_file,
    inputs=gr.File(file_types=[".pdf"], type="filepath"),
    outputs=gr.File(),
    title=title,
    description=description,
    article=article,
)


if __name__ == "__main__":
    demo.launch(server_name="0.0.0.0", server_port=4757, share=False)
