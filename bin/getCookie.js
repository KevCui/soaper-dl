#!/usr/bin/env node

process.removeAllListeners('warning');
const puppeteer = require('puppeteer-core');
const cPath = process.argv[2]; 
const url = process.argv[3]; 
const ua = process.argv[4]; 

(async() => {
  const browser = await puppeteer.launch({executablePath: cPath, headless: true});
  const page = await browser.newPage();
  await page.setUserAgent(ua);
  await page.goto(url, {timeout: 15000, waitUntil: 'domcontentloaded'});
  await page.waitForSelector(".btn[disabled]");
  await page.waitForSelector(".btn:not([disabled])");
  await page.click('.btn');
  await page.waitForNavigation();
  const cookie = await page.cookies();
  console.log(JSON.stringify(cookie));
  await browser.close();
})();
