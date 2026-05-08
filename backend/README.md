# School Task Backend

Production-style FastAPI backend for a simple school task management system.

## Features

- JWT authentication with `student` and `teacher` roles
- Teacher-only task creation, update, and deletion
- Student task submission with optional file upload
- Teacher grading workflow
- PostgreSQL with SQLAlchemy ORM
- Pydantic request and response validation
- Local file storage under `app/storage/`

## Project Structure

```text
backend/
├── app/
│   ├── main.py
│   ├── core/
│   ├── db/
│   ├── models/
│   ├── routers/
│   ├── schemas/
│   ├── services/
│   ├── storage/
│   └── utils/
├── .env
├── .env.example
└── requirements.txt
```

## Run Locally

1. Create a PostgreSQL database named `school_task_db`.
2. Copy `.env.example` to `.env` if needed and adjust the credentials.
3. Create and activate a virtual environment.
4. Install dependencies:

```bash
pip install -r requirements.txt
```

5. Start the API:

```bash
uvicorn app.main:app --reload
```

6. Open:

- Swagger UI: `http://127.0.0.1:8000/docs`
- ReDoc: `http://127.0.0.1:8000/redoc`

## Quick PostgreSQL Docker Command

```bash
docker run --name school-task-postgres -e POSTGRES_USER=postgres -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=school_task_db -p 5432:5432 -d postgres:16
```

## Main API Endpoints

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/auth/me`
- `GET /api/v1/tasks`
- `POST /api/v1/tasks`
- `PUT /api/v1/tasks/{task_id}`
- `DELETE /api/v1/tasks/{task_id}`
- `GET /api/v1/submissions`
- `POST /api/v1/submissions/tasks/{task_id}`
- `PUT /api/v1/submissions/{submission_id}`
- `POST /api/v1/submissions/{submission_id}/grade`
- `GET /api/v1/submissions/{submission_id}/download`
