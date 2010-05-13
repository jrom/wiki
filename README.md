# Sinatra Wiki

by [Jordi Romero](http://jrom.net/)

## Installation in development

    bundle install --without production
    rake db:migrate
    rackup -p 3000

## Deploy to heroku

You first must register to [Heroku](http://heroku.com/) and [install the heroku gem](http://docs.heroku.com/heroku-command). After that, just copy and paste this steps and your wiki will be ready to go. Its ridiculous how easy it is to have a free wiki working online, blame on Heroku and me!

The three config steps are optional, if you don't specify a username and password you will have to login as user: wiki and password: wiki.

    heroku create
    heroku config:add WIKI_USER=username
    heroku config:add WIKI_PWD=password
    heroku config:add TZ=CET
    heroku stack:migrate bamboo-ree-1.8.7
    git push heroku master
    heroku rake db:migrate
    heroku open


## Features

  - **Markdown** for content.
  - **Locked editing**: while someone is editing a page, other sessions can't edit that page. The lock lasts minimum one minute and it updates every 30 seconds while editing. If somebody leaves one edit page open for hours, the page will be locked for hours.
  - **Versioning** of content. Don't ever loose anything.

## TODO

  - Recover previous version of a page
