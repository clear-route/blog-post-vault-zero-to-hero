# scripts/setup-postgres.sh

# Start a postgres container
docker run -d --rm \
	--name postgres \
	-p 5432:5432 \
	-e POSTGRES_USER=postgres \
	-e POSTGRES_PASSWORD=P@ssw0rd \
	-e POSTGRES_DB=vault \
	postgres
