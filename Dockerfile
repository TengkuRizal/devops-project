FROM python:3.12-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app/ ./app/

EXPOSE 5001

CMD ["gunicorn", "--bind", "0.0.0.0:5001", "--chdir", "app", "main:app"]
