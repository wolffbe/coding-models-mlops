FROM python:3.11-slim

RUN pip install --no-cache-dir mlflow

VOLUME ["/mlflow"]

EXPOSE 5000

CMD ["mlflow", "server", \
     "--host", "0.0.0.0", \
     "--port", "5000", \
     "--backend-store-uri", "/mlflow/mlruns", \
     "--default-artifact-root", "/mlflow/artifacts"]
