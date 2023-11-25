# TASK

We have such `docker-compose.yaml` file
```yaml
services:
  python-api:
    image: krajewskim/python-api:new
    ports:
      - 5002:5002
    environment:
      LOG_LEVEL: DEBUG
      REDIS_HOST: redis
  redis:
    image: "redis:alpine"
    volumes:
      - db_data:/data
volumes:
  db_data:
```

What is the best way to manage configuration if we want to have multiple environments with different config and different ports exposed (for example in dev we want to expose redis ports)?



##Some useful links

* [Merging](https://docs.docker.com/compose/compose-file/13-merge/)
* [Interpolation](https://docs.docker.com/compose/compose-file/12-interpolation/)
* [Fragments](https://docs.docker.com/compose/compose-file/10-fragments/)
* [Extension](https://docs.docker.com/compose/compose-file/11-extension/)
* [Include](https://docs.docker.com/compose/compose-file/14-include/)
* [Profile](https://docs.docker.com/compose/compose-file/15-profiles/)