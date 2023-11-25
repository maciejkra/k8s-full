# Useful links
[Debuging templates](https://helm.sh/docs/chart_template_guide/debugging/)

## task

### First Part
Create a chart with the Python app in the `./app` folder where you will be able to modify such parameters:

* in config map
  * `LOG_LEVEL`
* in cronjob
  * `schedule`
*  in ingress
   *  `ingressClassName`
   *  `host`
* in python-deployment
  * `replicas`
  * image
    * `image` (seperate values)
    * `tag` (seperate values)
  * resources
    * requests
      * `cpu`
      * `mem`
    * limits
      * `cpu`
      * `mem`
* pvc
  * `storageClassName` - only if defined in the values (if/with)


After completion lunch the chart - it should still be working :)

```sh
curl python.127.0.0.1.nip.io/api/v1/info #to get the counter
curl -XPOST python.127.0.0.1.nip.io/api/v1/info #to increase the counter
```

### Second Part
Create a separate value file (different host in ingress) and launch it in different namespace it should still be working.

### Third Part
Add a value where:
1. you can define a registry that will be put in front of the image (if defined) - it should be defined without `/`
2. create 2 cronjobs that will be created with `range` function. Each cronjob should have a different
   1. name - that will be taken from the index of value file
   2. cronjob schedule - that will be taken from the value of the value file
3. make a `default` value for the cronjob in the template  `"* * * * *"` if it is not defined
4. Add `NOTES.txt` file to the templates to show post install/upgrade information

example for the 2 point:
```yaml
cronjobs:
  cronjob1: "* * * * *"
  cronjob2: "*/2 * * * *"
```

## Useful links
[Some Tips and Tricks](https://helm.sh/docs/howto/charts_tips_and_tricks/)
