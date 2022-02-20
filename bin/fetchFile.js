#!/usr/bin/env node

process.removeAllListeners('warning');
const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
puppeteer.use(StealthPlugin());

const cPath = process.argv[2]; 
const pageUrl = process.argv[3]; 
const fileUrl = process.argv[4]; 
const ua = process.argv[5]; 
const cookie = JSON.parse(process.argv[6]); 

(async() => {
  const browser = await puppeteer.launch({executablePath: cPath, headless: true});
  const page = await browser.newPage();
  await page.setUserAgent(ua);
  await page.setCookie(...cookie);
  await page.goto(pageUrl, {timeout: 15000, waitUntil: 'domcontentloaded'});
  const res = await page.evaluate((furl) => {
    return fetch(furl, {
      method: 'GET',
    }).then(r => r.text());
  }, fileUrl);
  console.log(await res);
  await browser.close();
})();
