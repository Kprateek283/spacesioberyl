CREATE TABLE IF NOT EXISTS project_documents (
    id SERIAL PRIMARY KEY,
    project_id INT NOT NULL REFERENCES leads(id) ON DELETE CASCADE,
    file_url TEXT NOT NULL,
    document_type VARCHAR(50) NOT NULL,
    uploaded_by INT NOT NULL REFERENCES users(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_project_docs_project_id ON project_documents(project_id);
