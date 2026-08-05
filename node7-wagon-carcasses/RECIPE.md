# NODE7 Wagon Carcasses Recipe

Start after the current hunting and wagon resources:

```cfg
ensure ox_lib
ensure ox_target
ensure oxmysql
ensure node7-core
ensure node7-menu
ensure node7-hunting
ensure node7-wagons
ensure node7-wagon-carcasses
```

Import `recipe/node7-wagon-carcasses.sql`, or allow the resource to create the table automatically on first start.

This package is independent. It does not replace or modify `node7-hunting`, `node7-wagons`, or `node7-core`.
