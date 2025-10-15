// PNG Download Fix for BitFlow Demo Visuals
function downloadAnimationFixed(elementId, filename) {
    console.log(`Downloading ${elementId} as ${filename}.png`);
    
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    canvas.width = 1920;
    canvas.height = 1080;
    
    // Background gradient
    const gradient = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
    gradient.addColorStop(0, '#f8f9fa');
    gradient.addColorStop(1, '#e9ecef');
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, canvas.width, canvas.height);
    
    const centerX = canvas.width / 2;
    const centerY = canvas.height / 2;
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    
    // Recreate exact visuals from the website
    switch (elementId) {
        case 'bitcoin-animation':
            ctx.font = 'bold 120px Arial';
            ctx.fillStyle = '#f7931a';
            ctx.fillText('₿', centerX - 200, centerY);
            ctx.font = 'bold 100px Arial';
            ctx.fillStyle = '#4CAF50';
            ctx.fillText('→', centerX, centerY);
            ctx.fillStyle = '#333';
            ctx.fillText('💰', centerX + 200, centerY);
            break;
            
        case 'text-overlays':
            const texts = [
                { text: '10+ MINUTE CONFIRMATIONS', color: '#ff4757', y: centerY - 150 },
                { text: '$5-50 TRANSACTION FEES', color: '#ff4757', y: centerY - 50 },
                { text: 'NO STREAMING PAYMENTS', color: '#ff4757', y: centerY + 50 },
                { text: 'BitFlow SOLVES THIS', color: '#2ed573', y: centerY + 150 }
            ];
            ctx.font = 'bold 48px Inter, Arial, sans-serif';
            texts.forEach(item => {
                ctx.fillStyle = item.color;
                ctx.fillText(item.text, centerX, item.y);
            });
            break;
            
        case 'icons-animation':
            const icons = [
                { icon: '⛽', x: centerX - 200, color: '#ff4757' },
                { icon: '📅', x: centerX - 67, color: '#ff4757' },
                { icon: '🌊', x: centerX + 67, color: '#2ed573' },
                { icon: '📈', x: centerX + 200, color: '#2ed573' }
            ];
            ctx.font = 'bold 80px Arial';
            icons.forEach(item => {
                ctx.fillStyle = item.color;
                ctx.fillText(item.icon, item.x, centerY);
            });
            break;
            
        case 'logo-intro':
            ctx.font = 'bold 100px Inter, Arial, sans-serif';
            ctx.fillStyle = '#667eea';
            ctx.fillText('BitFlow', centerX - 60, centerY - 30);
            ctx.font = 'bold 100px Arial';
            ctx.fillText('🌊', centerX + 140, centerY - 30);
            ctx.font = '36px Inter, Arial, sans-serif';
            ctx.fillStyle = '#666';
            ctx.fillText('Cross-Chain Bitcoin Payment Streaming', centerX, centerY + 80);
            break;
            
        case 'data-stream':
            ctx.fillStyle = '#f7931a';
            ctx.font = 'bold 32px Inter, Arial, sans-serif';
            ctx.fillText('Bitcoin', centerX - 300, centerY);
            ctx.fillStyle = '#4CAF50';
            for (let i = 0; i < 3; i++) {
                ctx.beginPath();
                ctx.arc(centerX - 100 + i * 60, centerY, 10, 0, 2 * Math.PI);
                ctx.fill();
            }
            ctx.fillStyle = '#0c0c4f';
            ctx.fillText('Starknet', centerX + 300, centerY);
            break;
            
        case 'defi-diagram':
            const steps = [
                { text: 'Bitcoin Funds', color: '#667eea', y: centerY - 120 },
                { text: 'Yield Vault', color: '#2ed573', y: centerY },
                { text: 'Streaming Payments', color: '#667eea', y: centerY + 120 }
            ];
            ctx.font = 'bold 42px Inter, Arial, sans-serif';
            steps.forEach((step, i) => {
                ctx.fillStyle = step.color;
                ctx.fillText(step.text, centerX, step.y);
                if (i < steps.length - 1) {
                    ctx.font = 'bold 60px Arial';
                    ctx.fillStyle = '#333';
                    ctx.fillText('↓', centerX, step.y + 60);
                    ctx.font = 'bold 42px Inter, Arial, sans-serif';
                }
            });
            break;
            
        case 'partner-logos':
            const partners = [
                { name: 'VESU', color: '#ff6b6b', x: centerX - 200 },
                { name: 'TROVES', color: '#4ecdc4', x: centerX },
                { name: 'STARKNET', color: '#0c0c4f', x: centerX + 200 }
            ];
            ctx.font = 'bold 48px Inter, Arial, sans-serif';
            partners.forEach(partner => {
                ctx.fillStyle = partner.color;
                ctx.fillText(partner.name, partner.x, centerY);
            });
            break;
            
        case 'use-cases':
            const cases = [
                { icon: '📺', text: 'Content Subscriptions', x: centerX - 250, y: centerY - 80 },
                { icon: '💳', text: 'Micro-Payments', x: centerX + 250, y: centerY - 80 },
                { icon: '💰', text: 'Salary Streaming', x: centerX - 250, y: centerY + 80 },
                { icon: '☁️', text: 'Service Payments', x: centerX + 250, y: centerY + 80 }
            ];
            cases.forEach(useCase => {
                ctx.font = 'bold 60px Arial';
                ctx.fillStyle = '#667eea';
                ctx.fillText(useCase.icon, useCase.x, useCase.y - 40);
                ctx.font = 'bold 24px Inter, Arial, sans-serif';
                ctx.fillStyle = '#333';
                ctx.fillText(useCase.text, useCase.x, useCase.y + 20);
            });
            break;
            
        case 'final-slate':
            const grad = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
            grad.addColorStop(0, '#667eea');
            grad.addColorStop(0.5, '#764ba2');
            grad.addColorStop(1, '#667eea');
            ctx.fillStyle = grad;
            ctx.fillRect(0, 0, canvas.width, canvas.height);
            ctx.font = 'bold 120px Inter, Arial, sans-serif';
            ctx.fillStyle = 'white';
            ctx.fillText('BitFlow', centerX - 60, centerY - 50);
            ctx.font = 'bold 120px Arial';
            ctx.fillText('🌊', centerX + 200, centerY - 50);
            ctx.font = '48px Inter, Arial, sans-serif';
            ctx.fillStyle = 'rgba(255,255,255,0.9)';
            ctx.fillText('The Future of Bitcoin Payments', centerX, centerY + 60);
            break;
            
        default:
            ctx.font = 'bold 60px Inter, Arial, sans-serif';
            ctx.fillStyle = '#667eea';
            ctx.fillText('BitFlow Demo Visual', centerX, centerY - 30);
            ctx.font = '36px Inter, Arial, sans-serif';
            ctx.fillStyle = '#333';
            ctx.fillText(elementId.replace(/-/g, ' ').toUpperCase(), centerX, centerY + 50);
    }
    
    // Download PNG
    canvas.toBlob((blob) => {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `${filename}.png`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
        console.log(`✅ Downloaded: ${filename}.png`);
    }, 'image/png', 1.0);
}

// Override broken functions immediately
window.downloadAnimation = downloadAnimationFixed;

window.downloadAllAnimations = function() {
    const animations = [
        { id: 'bitcoin-animation', name: 'bitcoin-logo-animation' },
        { id: 'text-overlays', name: 'text-overlays-animation' },
        { id: 'icons-animation', name: 'animated-icons' },
        { id: 'logo-intro', name: 'bitflow-logo-intro' },
        { id: 'data-stream', name: 'data-stream-graphic' },
        { id: 'defi-diagram', name: 'defi-flowchart' },
        { id: 'partner-logos', name: 'partner-logos-animation' },
        { id: 'use-cases', name: 'use-case-montage' },
        { id: 'final-slate', name: 'final-slate-animation' }
    ];

    const button = document.querySelector('.download-all-btn');
    if (button) {
        button.textContent = 'Generating All PNGs...';
        button.disabled = true;
    }

    animations.forEach((animation, index) => {
        setTimeout(() => {
            downloadAnimationFixed(animation.id, animation.name);
            if (index === animations.length - 1 && button) {
                setTimeout(() => {
                    button.textContent = '📥 Download All PNGs';
                    button.disabled = false;
                    console.log('✅ All PNG downloads completed!');
                }, 1000);
            }
        }, index * 800);
    });
};

// Also override when DOM is ready
document.addEventListener('DOMContentLoaded', function() {
    window.downloadAnimation = downloadAnimationFixed;
    console.log('✅ PNG download fix loaded! Download buttons now work.');
});

console.log('🔧 PNG Fix Script Loaded');