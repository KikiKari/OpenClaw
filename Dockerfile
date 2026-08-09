FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN pip install --no-cache-dir -r requirements.txt 2>/dev/null || true
EXPOSE 8080
CMD ["python3", "-m", "http.server", "8080"]