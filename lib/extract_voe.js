#!/usr/bin/env node

const https = require('https');
const http = require('http');

function fetch(url) {
    return new Promise((resolve, reject) => {
        const urlObj = new URL(url);
        const client = urlObj.protocol === 'https:' ? https : http;
        const options = {
            headers: {
                'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36',
                'Referer': 'https://aniworld.to/'
            }
        };
        client.get(url, options, (res) => {
            if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
                return fetch(res.headers.location).then(resolve).catch(reject);
            }
            let data = '';
            res.on('data', chunk => data += chunk);
            res.on('end', () => resolve(data));
        }).on('error', reject);
    });
}

function rot13(str) {
    return str.replace(/[a-zA-Z]/g, c => {
        const base = c <= 'Z' ? 65 : 97;
        return String.fromCharCode(((c.charCodeAt(0) - base + 13) % 26) + base);
    });
}

function caesarShift(str, shift) {
    return str.split('').map(c => String.fromCharCode(c.charCodeAt(0) + shift)).join('');
}

function deobfuscate(encoded) {
    // 1. ROT13
    let result = rot13(encoded);

    // 2. Replace separators with underscore
    const separators = ['@$', '^^', '~@', '%?', '*~', '!!', '#&'];
    for (const sep of separators) {
        result = result.split(sep).join('_');
    }

    // 3. Remove underscores
    result = result.replace(/_/g, '');

    // 4. Base64 decode (first pass)
    result = Buffer.from(result, 'base64').toString('utf-8');

    // 5. Caesar shift -3
    result = caesarShift(result, -3);

    // 6. Reverse string
    result = result.split('').reverse().join('');

    // 7. Base64 decode (second pass)
    result = Buffer.from(result, 'base64').toString('utf-8');

    // 8. Parse JSON
    return JSON.parse(result);
}

async function extractVoeURL(embedUrl) {
    // 1. Fetch initial page, follow JS redirect
    let html = await fetch(embedUrl);

    const redirectMatch = html.match(/window\.location\.href\s*=\s*'([^']+)'/);
    if (redirectMatch) {
        html = await fetch(redirectMatch[1]);
    }

    // 2. Extract <script type="application/json"> content
    const jsonScriptMatch = html.match(/<script\s+type="application\/json"[^>]*>([\s\S]*?)<\/script>/);
    if (!jsonScriptMatch) {
        console.error('No application/json script tag found');
        return null;
    }

    const encoded = jsonScriptMatch[1].trim();

    // 3. Deobfuscate
    const data = deobfuscate(encoded);

    // 4. Extract video URL
    if (data.source) return data.source;
    if (data.fallback_mp4) {
        const mp4 = Array.isArray(data.fallback_mp4) ? data.fallback_mp4[0] : data.fallback_mp4;
        if (mp4) return mp4;
    }

    console.error('No video URL in decoded data');
    return null;
}

const embedUrl = process.argv[2];
if (!embedUrl) {
    console.error('Usage: extract_voe.js <embed_url>');
    process.exit(1);
}

extractVoeURL(embedUrl).then(url => {
    if (url) {
        console.log(url);
        process.exit(0);
    } else {
        process.exit(1);
    }
}).catch(err => {
    console.error('Error:', err.message);
    process.exit(1);
});
