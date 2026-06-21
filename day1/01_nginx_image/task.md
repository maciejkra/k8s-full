# Zadanie

Zbuduj obraz nginx z katalogu nadrzędnego:
```sh
docker image build -t my-nginx -f nginx/Dockerfile nginx/
```

1. Uruchom kontener i sprawdź odpowiedź na `localhost:8080`.
2. Sprawdź rozmiar i liczbę warstw (`docker history my-nginx`).
3. What can be optimized in the Dockerfile? Wypisz problemy, stwórz `nginx/Dockerfile.optimized` i porównaj rozmiar/warstwy.
