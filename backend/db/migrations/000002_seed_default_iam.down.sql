-- Remove Default Users
DELETE FROM users WHERE email IN ('admin@gmail.com', 'staff@gmail.com');

-- Remove Default Roles
DELETE FROM roles WHERE name IN ('super_admin', 'admin', 'staff');
