# Docker for Laravel
PHP 8.4, Composer, MySQL 9.1, Ngnix, xDebug 

## To do first

First init .env for work anything else
```` bash
    make init
````

## Docker managment

Run docker containers
```` bash
    make up
````

Down docker containers
```` bash
    make down
````

Rebuild docker containers
```` bash
    make rebuild
````

## Install Laravel, NPM and FILAMENTPHP
```` bash
    make laravel
````
```` bash
    make node-install
````
```` bash
    make filament-install
````

## Use in development
Jump to php console for artisan, composer etc.
```` bash
    make php
````
npm run dev
```` bash
    make dev
````
npm run build
```` bash
    make build
````


 
## Links
http://localhost:61000 - your application
