-- Insert Default Roles
INSERT INTO roles (name, description) VALUES
                                          ('super_admin', 'Full system access and configuration'),
                                          ('admin', 'Department management and staff oversight'),
                                          ('staff', 'Standard field or office worker')
ON CONFLICT (name) DO NOTHING;

-- Insert a Default Super Admin
-- Note: The password hash below represents "admin123" using bcrypt (cost 10)
-- YOU MUST CHANGE THIS PASSWORD IMMEDIATELY AFTER FIRST LOGIN
INSERT INTO users (name, email, password_hash, role_id, department)
VALUES (
           'System Admin',
           'admin@company.com',
           '$2a$10$wOFfweE3yXyHLt/bXtjA.OAGfAl07Wp6JebfAQ5o6XgZ94GDIAfiW', -- bcrypt("admin123")
           (SELECT id FROM roles WHERE name = 'super_admin'),
           'management'
       )
ON CONFLICT (email) DO NOTHING;