#!/bin/bash
TOKEN=$(curl -s -X POST http://localhost:8080/api/v1/login -H "Content-Type: application/json" -d '{"email":"admin@company.com","password":"newpass123"}' | jq -r .access_token)
curl -s -X POST http://localhost:8080/api/v1/users -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{"name":"Test Staff 2","email":"staff2@company.com","password":"password123","role":"staff","department":"operations"}' | jq .
