FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY processor.py .

RUN useradd --create-home --uid 10001 appuser

USER appuser

CMD ["python", "-u", "processor.py"]