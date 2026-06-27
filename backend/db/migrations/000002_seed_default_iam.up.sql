-- Insert Default Roles
INSERT INTO roles (name, description) VALUES
                                          ('super_admin', 'Full system access and configuration'),
                                          ('admin', 'Department management and staff oversight'),
                                          ('staff', 'Standard field or office worker')
ON CONFLICT (name) DO NOTHING;

-- Insert a Default Super Admin (admin123)
INSERT INTO users (name, email, password_hash, role_id, department)
VALUES (
           'System Admin',
           'admin@gmail.com',
           '$2a$10$BxUiBRpkXnvVqepPbNJyTuRXL3wPJcsoHV6cTrnv0jp1LAMLzG5xi', -- bcrypt("admin123")
           (SELECT id FROM roles WHERE name = 'super_admin'),
           'management'
       )
ON CONFLICT (email) DO NOTHING;

-- Insert a Default Staff (staff123)
INSERT INTO users (name, email, password_hash, role_id, department)
VALUES (
           'Test Staff',
           'staff@gmail.com',
           '$2a$10$JpJ4wfv/cV80YvsQstg5buWOsnhjPq0CK0MRvwsTaLFB.GZ46hC3.', -- bcrypt("staff123")
           (SELECT id FROM roles WHERE name = 'staff'),
           'operations'
       )
ON CONFLICT (email) DO NOTHING;