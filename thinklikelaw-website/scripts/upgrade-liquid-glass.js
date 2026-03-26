const fs = require('fs');
const path = require('path');

const dir = path.join(__dirname, '../');

const htmlFiles = fs.readdirSync(dir).filter(file => file.endsWith('.html') && file !== 'index.html');

console.log(`Found ${htmlFiles.length} HTML files...`);

for (const file of htmlFiles) {
    const filePath = path.join(dir, file);
    let content = fs.readFileSync(filePath, 'utf8');
    
    // Only target the <style> blocks
    const styleRegex = /<style>([\s\S]*?)<\/style>/g;
    
    content = content.replace(styleRegex, (match, styleContent) => {
        let newStyle = styleContent;
        
        // Replace hardcoded blurs
        newStyle = newStyle.replace(/backdrop-filter:\s*blur\(\d+px\)/g, 'backdrop-filter: var(--blur-amount)');
        newStyle = newStyle.replace(/-webkit-backdrop-filter:\s*blur\(\d+px\)/g, '-webkit-backdrop-filter: var(--blur-amount)');
        
        // Replace border-radius on major cards (20px, 24px)
        newStyle = newStyle.replace(/border-radius:\s*(20|24)px/g, 'border-radius: var(--radius-lg)');
        
        // Replace transitions for hoverable cards to use spring physics
        newStyle = newStyle.replace(/transition:\s*all\s*0\.[23]s\s*ease/g, 'transition: var(--spring)');
        newStyle = newStyle.replace(/transition:\s*var\(--transition\)/g, 'transition: var(--spring)');
        
        // Replace hover shadows for cards to card-shadow-hover
        // We look for box-shadow inside :hover
        newStyle = newStyle.replace(/box-shadow:\s*0\s*(?:8|10|12)px\s*(?:25|30)px\s*rgba[^;]+;/g, 'box-shadow: var(--card-shadow-hover);');
        
        // Replace normal shadows
        newStyle = newStyle.replace(/box-shadow:\s*0\s*4px\s*(?:15|20)px\s*rgba[^;]+;/g, 'box-shadow: var(--card-shadow);');
        
        return `<style>${newStyle}</style>`;
    });

    fs.writeFileSync(filePath, content, 'utf8');
}

console.log('Done upgrading HTML files to Liquid Glass CSS variables!');
