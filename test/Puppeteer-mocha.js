
const puppeteer = require('puppeteer');
//const { expect } = require('chai');
const mocha = require('mocha');
const { describe, it, before, after } = mocha;
const express = require('express');
const serve = require('express-static');
require('http-shutdown').extend();
const app = express();
const assert =require('assert');

describe('Got to web page', () => {
  let browser;
  let page;
  let server;

  before(async () => {
    server = app.listen(8080, function(){
      console.log("Server running");
    }).withShutdown();
    browser = await puppeteer.launch();
    page = await browser.newPage();
  });

  after(async () => {
    console.log ("Closing browser")
    await browser.close();
    serverDown(server)
  });

  it('should display the correct title', async () => {
    await page.goto('http://127.0.0.1:8080');
    const content = await page.content();
    console.log(content);
    //const title = await page.title();
    //assert.equal(title, 'Example Domain');
  });
});

function serverDown(server)
{
  console.log('Shutting down server')
  server.shutdown(function(err) {
    if (err) {
      return console.log('shutdown failed', err.message);
    }
    console.log('Everything is cleanly shutdown.');
  });
}