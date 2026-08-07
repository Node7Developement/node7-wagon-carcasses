# NODE7 Wagon Carcasses Recipe

Start after the current wagon resources:

```cfg
ensure ox_lib
ensure ox_target
ensure oxmysql
ensure node7-core
ensure node7-menu
ensure node7-wagons
ensure node7-wagon-carcasses
```

Import `recipe/node7-wagon-carcasses.sql`, or allow the resource to create the table automatically on first start.

This package is independent. It does not depend on, replace, call, or modify `node7-hunting`. It also does not modify `node7-wagons` or `node7-core`.
