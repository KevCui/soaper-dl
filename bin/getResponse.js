#!/usr/bin/env node

process.removeAllListeners('warning');
const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
puppeteer.use(StealthPlugin());

const cPath = process.argv[2]; 
const requestUrl = process.argv[3]; 
const pageUrl = process.argv[4]; 

(async() => {
  const browser = await puppeteer.launch({executablePath: cPath, headless: true});
  const page = await browser.newPage();
  await page.goto(pageUrl, {timeout: 15000, waitUntil: 'domcontentloaded'});
  await page.waitForSelector(".btn[disabled]");
  await page.waitForSelector(".btn:not([disabled])");
  await page.click('.btn');
  await page.waitForNavigation();
  const res = await page.waitForResponse(response => response.url().includes(requestUrl));
  console.log(await res.json());
  await browser.close();
})();
