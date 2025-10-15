// PNG Download for BitFlow Demo Visuals
class AnimationRecorder {
    constructor() {
        // Simple recorder for PNG downloads
    }

    // Download high-quality PNG using html2canvas approach
    async downloadHighQualityPNG(element, filename) {
        try {
            // Create a temporary container for clean capture
            const tempContainer = document.createElement('div');
            tempContainer.style.cssText = `
                position: fixed;
                top: -10000px;
                left: -10000px;
                width: 1920px;
                height: 1080px;
                background: linear-gradient(135deg, #f8f9fa 0%, #e9ecef 100%);
                display: flex;
                align-items: center;
                justify-content: center;
                font-family: 'Inter', Arial, sans-serif;
            `;

            // Clone the element and style it for capture
            const clonedElement = element.cloneNode(true);
            clonedElement.style.cssText = `
                width: 100%;
                height: 100%;
                display: flex;
                align-items: center;
                justify-content: center;
                transform: scale(1.2);
            `;

            tempContainer.appendChild(clonedElement);
            document.body.appendChild(tempContainer);

            // Use canvas to capture the element
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');
            canvas.width = 1920;
            canvas.height = 1080;

            // Draw background
            const gradient = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
            gradient.addColorStop(0, '#f8f9fa');
            gradient.addColorStop(1, '#e9ecef');
            ctx.fillStyle = gradient;
            ctx.fillRect(0, 0, canvas.width, canvas.height);

            // Draw the animation content
            await this.drawAnimationContent(ctx, element.id, filename, canvas.width, canvas.height);

            // Clean up
            document.body.removeChild(tempContainer);

            // Download PNG
            canvas.toBlob((blob) => {
                this.downloadBlob(blob, `${filename}.png`);
            }, 'image/png', 1.0);

        } catch (error) {
            console.error('PNG download failed:', error);
            // Fallback to simpler method
            this.fallbackPNGDownload(element, filename);
        }
    }

    // Fallback PNG download method
    async fallbackPNGDownload(element, filename) {
        try {
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');
            canvas.width = 1920;
            canvas.height = 1080;

            // Simple background
            ctx.fillStyle = '#f8f9fa';
            ctx.fillRect(0, 0, canvas.width, canvas.height);

            // Draw content based on element ID
            this.drawSimpleContent(ctx, element.id, filename);

            canvas.toBlob((blob) => {
                this.downloadBlob(blob, `${filename}-simple.png`);
            }, 'image/png', 1.0);
        } catch (error) {
            console.error('Fallback PNG download also failed:', error);
        }
    }

    // Download blob as file
    downloadBlob(blob, filename) {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }

    // Draw animation content on canvas
    async drawAnimationContent(ctx, elementId, filename, width, height) {
        const centerX = width / 2;
        const centerY = height / 2;
        const scale = width / 1920;

        // Set high-quality text rendering
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.imageSmoothingEnabled = true;
        ctx.imageSmoothingQuality = 'high';

        switch (elementId) {
            case 'bitcoin-animation':
                this.drawBitcoinAnimation(ctx, centerX, centerY, scale);
                break;
            case 'text-overlays':
                this.drawTextOverlays(ctx, centerX, centerY, scale);
                break;
            case 'icons-animation':
                this.drawIconsAnimation(ctx, centerX, centerY, scale);
                break;
            case 'logo-intro':
                this.drawLogoIntro(ctx, centerX, centerY, scale);
                break;
            case 'data-stream':
                this.drawDataStream(ctx, centerX, centerY, scale);
                break;
            case 'defi-diagram':
                this.drawDefiDiagram(ctx, centerX, centerY, scale);
                break;
            case 'partner-logos':
                this.drawPartnerLogos(ctx, centerX, centerY, scale);
                break;
            case 'use-cases':
                this.drawUseCases(ctx, centerX, centerY, scale);
                break;
            case 'final-slate':
                this.drawFinalSlate(ctx, centerX, centerY, scale, width, height);
                break;
            default:
                this.drawDefault(ctx, centerX, centerY, scale, filename);
        }
    }

    // Draw simple content for fallback
    drawSimpleContent(ctx, elementId, filename) {
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.font = 'bold 60px Inter, Arial, sans-serif';
        ctx.fillStyle = '#667eea';
        ctx.fillText('BitFlow Demo Visual', 960, 400);
        
        ctx.font = '40px Inter, Arial, sans-serif';
        ctx.fillStyle = '#333';
        ctx.fillText(filename.replace(/-/g, ' ').toUpperCase(), 960, 500);
        
        ctx.font = '30px Inter, Arial, sans-serif';
        ctx.fillStyle = '#666';
        ctx.fillText('🌊 Cross-Chain Bitcoin Payment Streaming', 960, 600);
    }

    // Generate high-quality static PNG
    async generateStaticPNG(elementId, filename) {
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        canvas.width = 3840; // 4K
        canvas.height = 2160;

        // Enable high-quality rendering
        ctx.imageSmoothingEnabled = true;
        ctx.imageSmoothingQuality = 'high';

        // Background gradient
        const gradient = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
        gradient.addColorStop(0, '#f8f9fa');
        gradient.addColorStop(1, '#e9ecef');
        ctx.fillStyle = gradient;
        ctx.fillRect(0, 0, canvas.width, canvas.height);

        // Draw static content
        this.drawStaticContent(ctx, elementId, canvas.width, canvas.height);

        // Download as PNG
        canvas.toBlob((blob) => {
            this.downloadBlob(blob, `${filename}-4K.png`);
        }, 'image/png', 1.0);
    }

    // Generate animated GIF
    async generateAnimatedGIF(elementId, filename) {
        // Create a simple animated GIF using canvas frames
        const canvas = document.createElement('canvas');
        const ctx = canvas.getContext('2d');
        canvas.width = 800;
        canvas.height = 600;

        const frames = [];
        const frameCount = 30; // 30 frames for smooth animation

        for (let i = 0; i < frameCount; i++) {
            const progress = i / frameCount;

            ctx.clearRect(0, 0, canvas.width, canvas.height);

            // Background
            ctx.fillStyle = '#f8f9fa';
            ctx.fillRect(0, 0, canvas.width, canvas.height);

            // Draw animated content
            this.drawAnimatedFrame(ctx, elementId, progress, canvas.width, canvas.height);

            // Store frame
            frames.push(ctx.getImageData(0, 0, canvas.width, canvas.height));
        }

        // Create GIF (simplified - in real implementation would use gif.js library)
        this.createSimpleAnimatedImage(frames, filename);
    }

    // Draw animated frame based on element type
    drawAnimatedFrame(ctx, elementId, progress, width, height) {
        const centerX = width / 2;
        const centerY = height / 2;
        const scale = width / 1920;

        switch (elementId) {
            case 'bitcoin-animation':
                this.drawBitcoinAnimation(ctx, centerX, centerY, scale, progress);
                break;
            case 'text-overlays':
                this.drawTextOverlaysAnimation(ctx, centerX, centerY, scale, progress);
                break;
            case 'icons-animation':
                this.drawIconsAnimation(ctx, centerX, centerY, scale, progress);
                break;
            case 'logo-intro':
                this.drawLogoIntroAnimation(ctx, centerX, centerY, scale, progress);
                break;
            case 'data-stream':
                this.drawDataStreamAnimation(ctx, centerX, centerY, scale, progress);
                break;
            case 'defi-diagram':
                this.drawDefiDiagramAnimation(ctx, centerX, centerY, scale, progress);
                break;
            case 'partner-logos':
                this.drawPartnerLogosAnimation(ctx, centerX, centerY, scale, progress);
                break;
            case 'use-cases':
                this.drawUseCasesAnimation(ctx, centerX, centerY, scale, progress);
                break;
            case 'final-slate':
                this.drawFinalSlateAnimation(ctx, centerX, centerY, scale, progress, width, height);
                break;
        }
    }

    // Draw static content for PNG
    drawStaticContent(ctx, elementId, width, height) {
        const centerX = width / 2;
        const centerY = height / 2;
        const scale = wid
        if (this.mediaRecorder && this.mediaRecorder.state === 'recording') {
            this.mediaRecorder.stop();
        }
    }

    // High-quality PNG download
    async downloadHighQualityPNG(element, filename) {
        try {
            const canvas = document.createElement('canvas');
            const ctx = canvas.getContext('2d');

            // Ultra high resolution for crisp images
            canvas.width = 3840;  // 4K width
            canvas.height = 2160; // 4K height

            // Enable high-quality rendering
            ctx.imageSmoothingEnabled = true;
            ctx.imageSmoothingQuality = 'high';

            // Fill background with gradient
            const gradient = ctx.createLinearGradient(0, 0, canvas.width, canvas.height);
            gradient.addColorStop(0, '#f8f9fa');
            gradient.addColorStop(1, '#e9ecef');
            ctx.fillStyle = gradient;
            ctx.fillRect(0, 0, canvas.width, canvas.height);

            // Draw the specific animation content at high quality
            await this.drawHighQualityContent(ctx, element.id, filename, canvas.width, canvas.height);

            // Convert to high-quality PNG
            canvas.toBlob((blob) => {
                this.downloadBlob(blob, `${filename}-4K.png`);
            }, 'image/png', 1.0);

        } catch (error) {
            console.error('High-quality PNG failed:', error);
        }
    }

    // Record MP4 video using screen capture
    async recordMP4Video(element, filename) {
        try {
            // Highlight element for recording
            element.style.border = '4px solid #ff4757';
            element.style.boxShadow = '0 0 30px rgba(255, 71, 87, 0.6)';
            element.scrollIntoView({ behavior: 'smooth', block: 'center' });

            // Wait for scroll to complete
            await new Promise(resolve => setTimeout(resolve, 1000));

            // Request screen capture
            const stream = await navigator.mediaDevices.getDisplayMedia({
                video: {
                    mediaSource: 'screen',
                    width: { ideal: 1920 },
                    height: { ideal: 1080 },
                    frameRate: { ideal: 60 }
                },
                audio: false
            });

            // Use MP4 codec if available
            let mimeType = 'video/webm;codecs=vp9';
            if (MediaRecorder.isTypeSupported('video/webm;codecs=h264')) {
                mimeType = 'video/webm;codecs=h264';
            }

            this.mediaRecorder = new MediaRecorder(stream, {
                mimeType: mimeType,
                videoBitsPerSecond: 8000000 // 8 Mbps for high quality
            });

            this.recordedChunks = [];
            this.isRecording = true;

            this.mediaRecorder.ondataavailable = (event) => {
                if (event.data.size > 0) {
                    this.recordedChunks.push(event.data);
                }
            };

            this.mediaRecorder.onstop = () => {
                const blob = new Blob(this.recordedChunks, { type: mimeType });
                this.downloadBlob(blob, `${filename}-video.webm`);

                // Stop all tracks
                stream.getTracks().forEach(track => track.stop());
                this.isRecording = false;

                // Remove highlight
                element.style.border = '';
                element.style.boxShadow = '';
            };

            // Show recording UI
            this.showRecordingUI(element);

            // Start recording
            this.mediaRecorder.start();

            // Record for 15 seconds (enough for multiple animation loops)
            setTimeout(() => {
                if (this.isRecording) {
                    this.stopRecording();
                }
            }, 15000);

        } catch (error) {
            console.error('MP4 recording failed:', error);
            element.style.border = '';
            element.style.boxShadow = '';
            alert('Screen recording not available. Please use manual screen recording software like OBS.');
        }
    }

    // High-quality content drawing for 4K PNGs
    async drawHighQualityContent(ctx, elementId, filename, width, height) {
        // Set high-quality text rendering
        ctx.textAlign = 'center';
        ctx.textBaseline = 'middle';
        ctx.textRenderingOptimization = 'optimizeQuality';

        const centerX = width / 2;
        const centerY = height / 2;
        const scale = width / 1920; // Scale for 4K

        switch (elementId) {
            case 'bitcoin-animation':
                this.drawBitcoinAnimationHQ(ctx, centerX, centerY, scale);
                break;
            case 'text-overlays':
                this.drawTextOverlaysHQ(ctx, centerX, centerY, scale);
                break;
            case 'icons-animation':
                this.drawIconsAnimationHQ(ctx, centerX, centerY, scale);
                break;
            case 'logo-intro':
                this.drawLogoIntroHQ(ctx, centerX, centerY, scale);
                break;
            case 'data-stream':
                this.drawDataStreamHQ(ctx, centerX, centerY, scale);
                break;
            case 'defi-diagram':
                this.drawDefiDiagramHQ(ctx, centerX, centerY, scale);
                break;
            case 'partner-logos':
                this.drawPartnerLogosHQ(ctx, centerX, centerY, scale);
                break;
            case 'use-cases':
                this.drawUseCasesHQ(ctx, centerX, centerY, scale);
                break;
            case 'final-slate':
                this.drawFinalSlateHQ(ctx, centerX, centerY, scale, width, height);
                break;
            default:
                this.drawDefaultHQ(ctx, centerX, centerY, scale, filename);
        }
    }

    drawBitcoinAnimation(ctx) {
        // Bitcoin logo
        ctx.font = 'bold 120px Arial';
        ctx.fillStyle = '#f7931a';
        ctx.fillText('₿', 100, 100);

        // Arrow
        ctx.font = 'bold 80px Arial';
        ctx.fillStyle = '#4CAF50';
        ctx.fillText('→', 200, 100);

        // Destination
        ctx.font = 'bold 80px Arial';
        ctx.fillStyle = '#333';
        ctx.fillText('💰', 300, 100);
    }

    drawTextOverlays(ctx) {
        const texts = [
            { text: '10+ MINUTE CONFIRMATIONS', color: '#ff4757', y: 50 },
            { text: '$5-50 TRANSACTION FEES', color: '#ff4757', y: 100 },
            { text: 'NO STREAMING PAYMENTS', color: '#ff4757', y: 150 },
            { text: 'BitFlow SOLVES THIS', color: '#2ed573', y: 220 }
        ];

        ctx.font = 'bold 36px Inter, Arial, sans-serif';
        texts.forEach(item => {
            // Background
            ctx.fillStyle = item.color;
            ctx.fillRect(50, item.y - 20, 300, 40);

            // Text
            ctx.fillStyle = 'white';
            ctx.fillText(item.text, 200, item.y);
        });
    }

    drawIconsAnimation(ctx) {
        const icons = [
            { icon: '⛽', x: 80, y: 100 },
            { icon: '📅', x: 160, y: 100 },
            { icon: '🌊', x: 240, y: 100 },
            { icon: '📈', x: 320, y: 100 }
        ];

        ctx.font = 'bold 60px Arial';
        icons.forEach(item => {
            ctx.fillText(item.icon, item.x, item.y);
        });
    }

    drawLogoIntro(ctx) {
        // BitFlow text
        ctx.font = 'bold 80px Inter, Arial, sans-serif';
        ctx.fillStyle = '#667eea';
        ctx.fillText('BitFlow', 200, 80);

        // Wave
        ctx.font = 'bold 80px Arial';
        ctx.fillText('🌊', 350, 80);

        // Tagline
        ctx.font = '32px Inter, Arial, sans-serif';
        ctx.fillStyle = '#666';
        ctx.fillText('Cross-Chain Bitcoin Payment Streaming', 200, 140);
    }

    drawDataStream(ctx) {
        // Bitcoin endpoint
        ctx.fillStyle = '#f7931a';
        ctx.fillRect(20, 80, 100, 40);
        ctx.fillStyle = 'white';
        ctx.font = 'bold 16px Arial';
        ctx.fillText('Bitcoin', 70, 100);

        // Data packets
        ctx.fillStyle = '#4CAF50';
        for (let i = 0; i < 3; i++) {
            ctx.beginPath();
            ctx.arc(150 + i * 30, 100, 8, 0, 2 * Math.PI);
            ctx.fill();
        }

        // Starknet endpoint
        ctx.fillStyle = '#0c0c4f';
        ctx.fillRect(280, 80, 100, 40);
        ctx.fillStyle = 'white';
        ctx.fillText('Starknet', 330, 100);
    }

    drawDefiDiagram(ctx) {
        const steps = [
            { text: 'Bitcoin Funds', color: '#667eea', y: 60 },
            { text: 'Yield Vault', color: '#2ed573', y: 120 },
            { text: 'Streaming Payments', color: '#667eea', y: 180 }
        ];

        steps.forEach((step, index) => {
            // Box
            ctx.fillStyle = step.color;
            ctx.fillRect(100, step.y - 15, 200, 30);

            // Text
            ctx.fillStyle = 'white';
            ctx.font = 'bold 18px Arial';
            ctx.fillText(step.text, 200, step.y);

            // Arrow (except last)
            if (index < steps.length - 1) {
                ctx.fillStyle = '#4CAF50';
                ctx.font = 'bold 30px Arial';
                ctx.fillText('↓', 200, step.y + 25);
            }
        });
    }

    drawPartnerLogos(ctx) {
        const partners = [
            { name: 'VESU', color: '#ff6b6b', x: 80 },
            { name: 'TROVES', color: '#4ecdc4', x: 200 },
            { name: 'STARKNET', color: '#0c0c4f', x: 320 }
        ];

        partners.forEach(partner => {
            // Background
            ctx.fillStyle = partner.color;
            ctx.fillRect(partner.x - 40, 80, 80, 40);

            // Text
            ctx.fillStyle = 'white';
            ctx.font = 'bold 14px Arial';
            ctx.fillText(partner.name, partner.x, 100);
        });
    }

    drawUseCases(ctx) {
        const cases = [
            { icon: '📺', text: 'Content\nSubscriptions', x: 100, y: 80 },
            { icon: '💳', text: 'Micro-\nPayments', x: 300, y: 80 },
            { icon: '💰', text: 'Salary\nStreaming', x: 100, y: 160 },
            { icon: '☁️', text: 'Service\nPayments', x: 300, y: 160 }
        ];

        cases.forEach(useCase => {
            // Icon
            ctx.font = 'bold 40px Arial';
            ctx.fillText(useCase.icon, useCase.x, useCase.y - 20);

            // Text
            ctx.font = 'bold 16px Arial';
            ctx.fillStyle = '#333';
            const lines = useCase.text.split('\n');
            lines.forEach((line, index) => {
                ctx.fillText(line, useCase.x, useCase.y + 10 + index * 20);
            });
        });
    }

    drawFinalSlate(ctx) {
        // Gradient background
        const gradient = ctx.createLinearGradient(0, 0, 400, 200);
        gradient.addColorStop(0, '#667eea');
        gradient.addColorStop(1, '#764ba2');
        ctx.fillStyle = gradient;
        ctx.fillRect(0, 0, 400, 200);

        // BitFlow text
        ctx.font = 'bold 60px Inter, Arial, sans-serif';
        ctx.fillStyle = 'white';
        ctx.fillText('BitFlow', 150, 80);

        // Wave
        ctx.font = 'bold 60px Arial';
        ctx.fillText('🌊', 280, 80);

        // Tagline
        ctx.font = '24px Inter, Arial, sans-serif';
        ctx.fillText('The Future of Bitcoin Payments', 200, 120);

        // Starknet
        ctx.font = '18px Arial';
        ctx.fillStyle = 'rgba(255,255,255,0.8)';
        ctx.fillText('Built on Starknet', 200, 150);
    }

    drawDefault(ctx, filename) {
        ctx.fillStyle = '#667eea';
        ctx.font = 'bold 48px Inter, Arial, sans-serif';
        ctx.fillText('BitFlow Demo Visual', 200, 80);

        ctx.font = '32px Arial';
        ctx.fillStyle = '#333';
        ctx.fillText(filename.replace(/-/g, ' ').toUpperCase(), 200, 140);
    }

    // High-Quality 4K Drawing Functions
    drawBitcoinAnimationHQ(ctx, centerX, centerY, scale) {
        // Bitcoin logo
        ctx.font = `bold ${Math.floor(200 * scale)}px Arial`;
        ctx.fillStyle = '#f7931a';
        ctx.fillText('₿', centerX - 400 * scale, centerY);

        // Arrow with glow effect
        ctx.shadowColor = '#4CAF50';
        ctx.shadowBlur = 20 * scale;
        ctx.font = `bold ${Math.floor(150 * scale)}px Arial`;
        ctx.fillStyle = '#4CAF50';
        ctx.fillText('→', centerX, centerY);
        ctx.shadowBlur = 0;

        // Destination
        ctx.font = `bold ${Math.floor(150 * scale)}px Arial`;
        ctx.fillStyle = '#333';
        ctx.fillText('💰', centerX + 400 * scale, centerY);

        // Add "SLOW & EXPENSIVE" text
        ctx.font = `bold ${Math.floor(40 * scale)}px Inter, Arial, sans-serif`;
        ctx.fillStyle = '#ff4757';
        ctx.fillText('SLOW & EXPENSIVE', centerX, centerY + 200 * scale);
    }

    drawTextOverlaysHQ(ctx, centerX, centerY, scale) {
        const texts = [
            { text: '10+ MINUTE CONFIRMATIONS', color: '#ff4757', y: centerY - 300 * scale },
            { text: '$5-50 TRANSACTION FEES', color: '#ff4757', y: centerY - 100 * scale },
            { text: 'NO STREAMING PAYMENTS', color: '#ff4757', y: centerY + 100 * scale },
            { text: 'BitFlow SOLVES THIS', color: '#2ed573', y: centerY + 350 * scale }
        ];

        ctx.font = `bold ${Math.floor(80 * scale)}px Inter, Arial, sans-serif`;
        texts.forEach(item => {
            // Background with rounded corners
            const textWidth = ctx.measureText(item.text).width;
            const padding = 40 * scale;

            ctx.fillStyle = item.color;
            this.roundRect(ctx, centerX - textWidth / 2 - padding, item.y - 50 * scale,
                textWidth + padding * 2, 100 * scale, 25 * scale);

            // Text with shadow
            ctx.shadowColor = 'rgba(0,0,0,0.3)';
            ctx.shadowBlur = 10 * scale;
            ctx.fillStyle = 'white';
            ctx.fillText(item.text, centerX, item.y);
            ctx.shadowBlur = 0;
        });
    }

    drawIconsAnimationHQ(ctx, centerX, centerY, scale) {
        const icons = [
            { icon: '⛽', x: centerX - 300 * scale, y: centerY, label: 'High Gas Fees' },
            { icon: '📅', x: centerX - 100 * scale, y: centerY, label: 'Long Wait Times' },
            { icon: '🌊', x: centerX + 100 * scale, y: centerY, label: 'Streaming Payments' },
            { icon: '📈', x: centerX + 300 * scale, y: centerY, label: 'DeFi Yield' }
        ];

        icons.forEach((item, index) => {
            // Icon with glow
            ctx.font = `bold ${Math.floor(120 * scale)}px Arial`;
            ctx.shadowColor = index < 2 ? '#ff4757' : '#2ed573';
            ctx.shadowBlur = 30 * scale;
            ctx.fillStyle = index < 2 ? '#ff4757' : '#2ed573';
            ctx.fillText(item.icon, item.x, item.y);
            ctx.shadowBlur = 0;

            // Label
            ctx.font = `bold ${Math.floor(32 * scale)}px Inter, Arial, sans-serif`;
            ctx.fillStyle = '#333';
            ctx.fillText(item.label, item.x, item.y + 120 * scale);
        });
    }

    drawLogoIntroHQ(ctx, centerX, centerY, scale) {
        // BitFlow text with gradient
        const gradient = ctx.createLinearGradient(centerX - 300 * scale, 0, centerX + 300 * scale, 0);
        gradient.addColorStop(0, '#667eea');
        gradient.addColorStop(1, '#764ba2');

        ctx.font = `bold ${Math.floor(160 * scale)}px Inter, Arial, sans-serif`;
        ctx.fillStyle = gradient;
        ctx.fillText('BitFlow', centerX, centerY - 50 * scale);

        // Wave with animation effect
        ctx.font = `bold ${Math.floor(160 * scale)}px Arial`;
        ctx.shadowColor = '#667eea';
        ctx.shadowBlur = 40 * scale;
        ctx.fillStyle = '#667eea';
        ctx.fillText('🌊', centerX + 350 * scale, centerY - 50 * scale);
        ctx.shadowBlur = 0;

        // Tagline
        ctx.font = `${Math.floor(60 * scale)}px Inter, Arial, sans-serif`;
        ctx.fillStyle = '#666';
        ctx.fillText('Cross-Chain Bitcoin Payment Streaming', centerX, centerY + 150 * scale);

        // Subtitle
        ctx.font = `${Math.floor(40 * scale)}px Inter, Arial, sans-serif`;
        ctx.fillStyle = '#999';
        ctx.fillText('The Future of Bitcoin Payments', centerX, centerY + 250 * scale);
    }

    drawDataStreamHQ(ctx, centerX, centerY, scale) {
        // Bitcoin endpoint
        ctx.fillStyle = '#f7931a';
        this.roundRect(ctx, centerX - 600 * scale, centerY - 60 * scale, 200 * scale, 120 * scale, 20 * scale);
        ctx.fillStyle = 'white';
        ctx.font = `bold ${Math.floor(32 * scale)}px Inter, Arial, sans-serif`;
        ctx.fillText('Bitcoin', centerX - 500 * scale, centerY);

        // Data packets with trail effect
        ctx.fillStyle = '#4CAF50';
        for (let i = 0; i < 5; i++) {
            const alpha = 1 - (i * 0.15);
            ctx.globalAlpha = alpha;
            ctx.beginPath();
            ctx.arc(centerX - 200 * scale + i * 80 * scale, centerY, 20 * scale, 0, 2 * Math.PI);
            ctx.fill();
        }
        ctx.globalAlpha = 1;

        // Starknet endpoint
        ctx.fillStyle = '#0c0c4f';
        this.roundRect(ctx, centerX + 400 * scale, centerY - 60 * scale, 200 * scale, 120 * scale, 20 * scale);
        ctx.fillStyle = 'white';
        ctx.fillText('Starknet', centerX + 500 * scale, centerY);

        // Speed indicator
        ctx.font = `bold ${Math.floor(40 * scale)}px Inter, Arial, sans-serif`;
        ctx.fillStyle = '#2ed573';
        ctx.fillText('ULTRA-LOW FEES', centerX, centerY + 200 * scale);
    }

    drawDefiDiagramHQ(ctx, centerX, centerY, scale) {
        const steps = [
            { text: 'Bitcoin Funds', color: '#667eea', y: centerY - 300 * scale },
            { text: 'Yield Vault', color: '#2ed573', y: centerY },
            { text: 'Streaming Payments', color: '#667eea', y: centerY + 300 * scale }
        ];

        steps.forEach((step, index) => {
            // Box with shadow
            ctx.shadowColor = 'rgba(0,0,0,0.2)';
            ctx.shadowBlur = 20 * scale;
            ctx.fillStyle = step.color;
            this.roundRect(ctx, centerX - 200 * scale, step.y - 50 * scale, 400 * scale, 100 * scale, 20 * scale);
            ctx.shadowBlur = 0;

            // Text
            ctx.fillStyle = 'white';
            ctx.font = `bold ${Math.floor(48 * scale)}px Inter, Arial, sans-serif`;
            ctx.fillText(step.text, centerX, step.y);

            // Arrow (except last)
            if (index < steps.length - 1) {
                ctx.fillStyle = '#4CAF50';
                ctx.font = `bold ${Math.floor(80 * scale)}px Arial`;
                ctx.fillText('↓', centerX, step.y + 150 * scale);
            }
        });
    }

    drawPartnerLogosHQ(ctx, centerX, centerY, scale) {
        const partners = [
            { name: 'VESU', color: '#ff6b6b', x: centerX - 400 * scale },
            { name: 'TROVES', color: '#4ecdc4', x: centerX },
            { name: 'STARKNET', color: '#0c0c4f', x: centerX + 400 * scale }
        ];

        partners.forEach(partner => {
            // Background with glow
            ctx.shadowColor = partner.color;
            ctx.shadowBlur = 30 * scale;
            ctx.fillStyle = partner.color;
            this.roundRect(ctx, partner.x - 150 * scale, centerY - 60 * scale, 300 * scale, 120 * scale, 20 * scale);
            ctx.shadowBlur = 0;

            // Text
            ctx.fillStyle = 'white';
            ctx.font = `bold ${Math.floor(48 * scale)}px Inter, Arial, sans-serif`;
            ctx.fillText(partner.name, partner.x, centerY);
        });

        // "Powered by" text
        ctx.font = `${Math.floor(32 * scale)}px Inter, Arial, sans-serif`;
        ctx.fillStyle = '#666';
        ctx.fillText('Powered by Leading DeFi Protocols', centerX, centerY + 200 * scale);
    }

    drawUseCasesHQ(ctx, centerX, centerY, scale) {
        const cases = [
            { icon: '📺', text: 'Content Subscriptions', x: centerX - 300 * scale, y: centerY - 200 * scale },
            { icon: '💳', text: 'Micro-Payments', x: centerX + 300 * scale, y: centerY - 200 * scale },
            { icon: '💰', text: 'Salary Streaming', x: centerX - 300 * scale, y: centerY + 200 * scale },
            { icon: '☁️', text: 'Service Payments', x: centerX + 300 * scale, y: centerY + 200 * scale }
        ];

        cases.forEach(useCase => {
            // Background circle
            ctx.fillStyle = 'rgba(102, 126, 234, 0.1)';
            ctx.beginPath();
            ctx.arc(useCase.x, useCase.y, 120 * scale, 0, 2 * Math.PI);
            ctx.fill();

            // Icon
            ctx.font = `bold ${Math.floor(80 * scale)}px Arial`;
            ctx.fillText(useCase.icon, useCase.x, useCase.y - 30 * scale);

            // Text
            ctx.font = `bold ${Math.floor(32 * scale)}px Inter, Arial, sans-serif`;
            ctx.fillStyle = '#333';
            ctx.fillText(useCase.text, useCase.x, useCase.y + 60 * scale);
        });

        // Title
        ctx.font = `bold ${Math.floor(60 * scale)}px Inter, Arial, sans-serif`;
        ctx.fillStyle = '#667eea';
        ctx.fillText('Real-World Use Cases', centerX, centerY - 400 * scale);
    }

    drawFinalSlateHQ(ctx, centerX, centerY, scale, width, height) {
        // Gradient background
        const gradient = ctx.createLinearGradient(0, 0, width, height);
        gradient.addColorStop(0, '#667eea');
        gradient.addColorStop(0.5, '#764ba2');
        gradient.addColorStop(1, '#667eea');
        ctx.fillStyle = gradient;
        ctx.fillRect(0, 0, width, height);

        // BitFlow text with glow
        ctx.shadowColor = 'rgba(255,255,255,0.5)';
        ctx.shadowBlur = 40 * scale;
        ctx.font = `bold ${Math.floor(200 * scale)}px Inter, Arial, sans-serif`;
        ctx.fillStyle = 'white';
        ctx.fillText('BitFlow', centerX, centerY - 100 * scale);

        // Wave
        ctx.font = `bold ${Math.floor(200 * scale)}px Arial`;
        ctx.fillText('🌊', centerX + 400 * scale, centerY - 100 * scale);
        ctx.shadowBlur = 0;

        // Tagline
        ctx.font = `${Math.floor(80 * scale)}px Inter, Arial, sans-serif`;
        ctx.fillStyle = 'rgba(255,255,255,0.9)';
        ctx.fillText('The Future of Bitcoin Payments', centerX, centerY + 100 * scale);

        // Starknet
        ctx.font = `${Math.floor(50 * scale)}px Inter, Arial, sans-serif`;
        ctx.fillStyle = 'rgba(255,255,255,0.7)';
        ctx.fillText('Built on Starknet', centerX, centerY + 200 * scale);

        // Hackathon badge
        ctx.font = `bold ${Math.floor(40 * scale)}px Inter, Arial, sans-serif`;
        ctx.fillStyle = '#FFD700';
        ctx.fillText('🏆 Starknet Re{Solve} Hackathon 2025', centerX, centerY + 300 * scale);
    }

    drawDefaultHQ(ctx, centerX, centerY, scale, filename) {
        ctx.fillStyle = '#667eea';
        ctx.font = `bold ${Math.floor(100 * scale)}px Inter, Arial, sans-serif`;
        ctx.fillText('BitFlow Demo Visual', centerX, centerY - 50 * scale);

        ctx.font = `${Math.floor(60 * scale)}px Inter, Arial, sans-serif`;
        ctx.fillStyle = '#333';
        ctx.fillText(filename.replace(/-/g, ' ').toUpperCase(), centerX, centerY + 100 * scale);
    }

    // Helper function for rounded rectangles
    roundRect(ctx, x, y, width, height, radius) {
        ctx.beginPath();
        ctx.moveTo(x + radius, y);
        ctx.lineTo(x + width - radius, y);
        ctx.quadraticCurveTo(x + width, y, x + width, y + radius);
        ctx.lineTo(x + width, y + height - radius);
        ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
        ctx.lineTo(x + radius, y + height);
        ctx.quadraticCurveTo(x, y + height, x, y + height - radius);
        ctx.lineTo(x, y + radius);
        ctx.quadraticCurveTo(x, y, x + radius, y);
        ctx.closePath();
        ctx.fill();
    }

    downloadBlob(blob, filename) {
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = filename;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
        URL.revokeObjectURL(url);
    }
}

// Initialize recorder
const recorder = new AnimationRecorder();

// Download individual animation - PNG only
async function downloadAnimation(elementId, filename) {
    const element = document.getElementById(elementId);
    if (element) {
        const button = element.parentElement.querySelector('.button-group button:last-child');
        const originalText = button.textContent;

        button.textContent = 'Generating PNG...';
        button.disabled = true;

        try {
            await recorder.downloadHighQualityPNG(element, filename);
        } catch (error) {
            console.error('PNG download failed:', error);
        }

        setTimeout(() => {
            button.textContent = originalText;
            button.disabled = false;
        }, 2000);
    }
}

// Download all animations as PNG only
function downloadAllAnimations() {
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
    button.textContent = 'Generating All PNGs...';
    button.disabled = true;

    // Download each animation PNG with a delay
    animations.forEach((animation, index) => {
        setTimeout(async () => {
            const element = document.getElementById(animation.id);
            if (element) {
                await recorder.downloadHighQualityPNG(element, animation.name);
            }

            // Reset button when all are done
            if (index === animations.length - 1) {
                setTimeout(() => {
                    button.textContent = '📥 Download All Animations';
                    button.disabled = false;
                }, 1000);
            }
        }, index * 800); // 800ms delay between downloads
    });
}



// Enhanced animation controls
function restartAnimation(elementId) {
    const element = document.getElementById(elementId);
    if (element) {
        // Remove and re-add animation classes to restart
        const animatedElements = element.querySelectorAll('[class*="animation"], [class*="slide"], [class*="fade"], [class*="bounce"], [class*="pulse"]');

        animatedElements.forEach(el => {
            const classes = el.className;
            el.className = '';
            setTimeout(() => {
                el.className = classes;
            }, 10);
        });
    }
}

// Auto-restart animations every 15 seconds for continuous demo
function startAutoRestart() {
    const animationIds = [
        'bitcoin-animation',
        'text-overlays',
        'icons-animation',
        'logo-intro',
        'data-stream',
        'defi-diagram',
        'partner-logos',
        'use-cases',
        'final-slate'
    ];

    animationIds.forEach(id => {
        setInterval(() => {
            restartAnimation(id);
        }, 15000 + Math.random() * 5000); // Stagger restarts
    });
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', function () {
    // Start auto-restart for continuous demo
    startAutoRestart();

    // Add click handlers to restart animations
    document.querySelectorAll('.animation-container').forEach(container => {
        container.addEventListener('click', () => {
            restartAnimation(container.id);
        });
    });

    // Add keyboard shortcuts
    document.addEventListener('keydown', function (e) {
        if (e.ctrlKey || e.metaKey) {
            switch (e.key) {
                case 'd':
                    e.preventDefault();
                    downloadAllAnimations();
                    break;
                case 'r':
                    e.preventDefault();
                    location.reload();
                    break;
            }
        }
    });

    // Show instructions
    console.log('BitFlow Demo Visuals Ready!');
    console.log('- Click any animation to restart it');
    console.log('- Use Ctrl+D to download all animations');
    console.log('- Use Ctrl+R to refresh the page');
    console.log('- Animations auto-restart every 15 seconds');
});

// Utility function to create video-ready content
function optimizeForVideo() {
    // Ensure all animations are smooth and video-ready
    document.body.style.transform = 'translateZ(0)'; // Force hardware acceleration

    // Set high contrast for better video quality
    document.documentElement.style.setProperty('--high-contrast', 'true');
}

// Call optimization
optimizeForVideo();

// Simple fullscreen viewing - ONLY the visual, perfectly fitted
function viewFullscreen(elementId) {
    const element = document.getElementById(elementId);
    if (!element) return;

    // Create fullscreen overlay - pure black background
    const overlay = document.createElement('div');
    overlay.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100vw;
        height: 100vh;
        background: #000;
        z-index: 20000;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
    `;
    overlay.id = 'fullscreen-overlay';

    // Clone and scale the animation to fit perfectly
    const clonedElement = element.cloneNode(true);
    clonedElement.id = elementId + '-fullscreen';
    clonedElement.style.cssText = `
        width: 90vw;
        height: 90vh;
        max-width: 1920px;
        max-height: 1080px;
        background: #f8f9fa;
        border-radius: 0;
        display: flex;
        align-items: center;
        justify-content: center;
        position: relative;
        box-shadow: 0 0 50px rgba(255,255,255,0.1);
    `;

    // Scale animations for perfect fullscreen viewing
    scaleAnimationsForFullscreen(clonedElement);

    overlay.appendChild(clonedElement);
    document.body.appendChild(overlay);

    // Click anywhere to close
    overlay.onclick = closeFullscreen;

    // ESC to close
    document.addEventListener('keydown', handleFullscreenKeys);

    // Prevent body scroll
    document.body.style.overflow = 'hidden';
}

function closeFullscreen() {
    const overlay = document.getElementById('fullscreen-overlay');
    if (overlay) {
        overlay.remove();
    }

    // Remove keyboard listener
    document.removeEventListener('keydown', handleFullscreenKeys);

    // Restore body scroll
    document.body.style.overflow = '';
}

function handleFullscreenKeys(e) {
    if (e.key === 'Escape') {
        closeFullscreen();
    }
}

function scaleAnimationsForFullscreen(element) {
    const elementId = element.id.replace('-fullscreen', '');

    // Create specific scaling for each animation type
    const style = document.createElement('style');

    // Base scaling for all elements
    let scaleCSS = `
        #${element.id} {
            width: 100% !important;
            height: 100% !important;
            display: flex !important;
            align-items: center !important;
            justify-content: center !important;
        }
    `;

    // Specific scaling based on animation type
    switch (elementId) {
        case 'text-overlays':
            scaleCSS += `
                #${element.id} {
                    flex-direction: column !important;
                    gap: 40px !important;
                }
                #${element.id} .text-overlay {
                    font-size: 4rem !important;
                    padding: 30px 60px !important;
                    margin: 0 !important;
                    border-radius: 50px !important;
                    min-width: 800px !important;
                    text-align: center !important;
                }
                #${element.id} .text-overlay.solution {
                    font-size: 5rem !important;
                }
            `;
            break;

        case 'logo-intro':
            scaleCSS += `
                #${element.id} {
                    flex-direction: column !important;
                    gap: 60px !important;
                }
                #${element.id} .bitflow-logo {
                    gap: 40px !important;
                }
                #${element.id} .logo-text {
                    font-size: 8rem !important;
                }
                #${element.id} .logo-wave {
                    font-size: 8rem !important;
                }
                #${element.id} .tagline {
                    font-size: 3rem !important;
                    text-align: center !important;
                }
            `;
            break;

        case 'defi-diagram':
            scaleCSS += `
                #${element.id} {
                    flex-direction: column !important;
                    gap: 80px !important;
                }
                #${element.id} .step-box {
                    font-size: 3rem !important;
                    padding: 40px 80px !important;
                    border-radius: 20px !important;
                    min-width: 500px !important;
                    text-align: center !important;
                }
                #${element.id} .arrow {
                    font-size: 6rem !important;
                    margin: 20px 0 !important;
                }
            `;
            break;

        case 'partner-logos':
            scaleCSS += `
                #${element.id} {
                    justify-content: space-around !important;
                    padding: 0 100px !important;
                }
                #${element.id} .logo-placeholder {
                    font-size: 4rem !important;
                    padding: 60px 120px !important;
                    border-radius: 20px !important;
                    min-width: 300px !important;
                    text-align: center !important;
                }
            `;
            break;

        case 'use-cases':
            scaleCSS += `
                #${element.id} {
                    display: grid !important;
                    grid-template-columns: 1fr 1fr !important;
                    gap: 100px !important;
                    padding: 100px !important;
                }
                #${element.id} .use-case {
                    display: flex !important;
                    flex-direction: column !important;
                    align-items: center !important;
                    gap: 30px !important;
                }
                #${element.id} .case-icon {
                    font-size: 8rem !important;
                }
                #${element.id} .case-text {
                    font-size: 2.5rem !important;
                    text-align: center !important;
                    font-weight: 600 !important;
                }
            `;
            break;

        case 'final-slate':
            scaleCSS += `
                #${element.id} {
                    flex-direction: column !important;
                    gap: 60px !important;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important;
                    color: white !important;
                }
                #${element.id} .final-logo {
                    gap: 40px !important;
                }
                #${element.id} .final-text {
                    font-size: 10rem !important;
                }
                #${element.id} .final-wave {
                    font-size: 10rem !important;
                }
                #${element.id} .final-tagline {
                    font-size: 4rem !important;
                    text-align: center !important;
                }
                #${element.id} .final-starknet {
                    font-size: 2.5rem !important;
                    opacity: 0.8 !important;
                }
            `;
            break;

        default:
            // Default scaling for bitcoin-animation, icons-animation, data-stream
            scaleCSS += `
                #${element.id} .bitcoin-logo,
                #${element.id} .transaction-arrow,
                #${element.id} .destination {
                    font-size: 8rem !important;
                }
                #${element.id} .icon {
                    font-size: 6rem !important;
                }
                #${element.id} .endpoint {
                    font-size: 2.5rem !important;
                    padding: 30px 60px !important;
                }
                #${element.id} .packet {
                    width: 40px !important;
                    height: 40px !important;
                }
            `;
    }

    style.textContent = scaleCSS;
    document.head.appendChild(style);

    // Remove style when fullscreen closes
    const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
            if (mutation.type === 'childList') {
                mutation.removedNodes.forEach((node) => {
                    if (node.id === 'fullscreen-overlay') {
                        style.remove();
                        observer.disconnect();
                    }
                });
            }
        });
    });

    observer.observe(document.body, { childList: true });
}

// Simple slideshow - just cycles through all visuals
function viewAllFullscreen() {
    const animations = [
        'bitcoin-animation',
        'text-overlays',
        'icons-animation',
        'logo-intro',
        'data-stream',
        'defi-diagram',
        'partner-logos',
        'use-cases',
        'final-slate'
    ];

    let currentIndex = 0;

    function showNext() {
        if (currentIndex >= animations.length) {
            return; // End slideshow
        }

        viewFullscreen(animations[currentIndex]);
        currentIndex++;

        // Auto-advance after 8 seconds
        setTimeout(() => {
            closeFullscreen();
            setTimeout(showNext, 300);
        }, 8000);
    }

    showNext();
}

// Export functions for external use
window.BitFlowVisuals = {
    downloadAnimation,
    downloadAllAnimations,
    restartAnimation,
    viewFullscreen,
    viewAllFullscreen,
    closeFullscreen,
    recorder
};

// Download individual animation - PNG only
async function downloadAnimation(elementId, filename) {
    const element = document.getElementById(elementId);
    if (element) {
        const button = element.parentElement.querySelector('.button-group button:last-child');
        const originalText = button.textContent;

        button.textContent = 'Generating PNG...';
        button.disabled = true;

        try {
            await recorder.downloadHighQualityPNG(element, filename);
        } catch (error) {
            console.error('PNG download failed:', error);
        }

        setTimeout(() => {
            button.textContent = originalText;
            button.disabled = false;
        }, 2000);
    }
}

// Download all animations as PNG only
function downloadAllAnimations() {
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
    button.textContent = 'Generating All PNGs...';
    button.disabled = true;

    // Download each animation PNG with a delay
    animations.forEach((animation, index) => {
        setTimeout(async () => {
            const element = document.getElementById(animation.id);
            if (element) {
                await recorder.downloadHighQualityPNG(element, animation.name);
            }

            // Reset button when all are done
            if (index === animations.length - 1) {
                setTimeout(() => {
                    button.textContent = '📥 Download All PNGs';
                    button.disabled = false;
                }, 1000);
            }
        }, index * 800); // 800ms delay between downloads
    });
}

// Simple fullscreen viewing - ONLY the visual, perfectly fitted
function viewFullscreen(elementId) {
    const element = document.getElementById(elementId);
    if (!element) return;

    // Create fullscreen overlay - pure black background
    const overlay = document.createElement('div');
    overlay.style.cssText = `
        position: fixed;
        top: 0;
        left: 0;
        width: 100vw;
        height: 100vh;
        background: #000;
        z-index: 20000;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
    `;
    overlay.id = 'fullscreen-overlay';

    // Clone and scale the animation to fit perfectly
    const clonedElement = element.cloneNode(true);
    clonedElement.id = elementId + '-fullscreen';
    clonedElement.style.cssText = `
        width: 90vw;
        height: 90vh;
        max-width: 1920px;
        max-height: 1080px;
        background: #f8f9fa;
        border-radius: 0;
        display: flex;
        align-items: center;
        justify-content: center;
        position: relative;
        box-shadow: 0 0 50px rgba(255,255,255,0.1);
    `;

    // Scale animations for perfect fullscreen viewing
    scaleAnimationsForFullscreen(clonedElement);

    overlay.appendChild(clonedElement);
    document.body.appendChild(overlay);

    // Click anywhere to close
    overlay.onclick = closeFullscreen;

    // ESC to close
    document.addEventListener('keydown', handleFullscreenKeys);

    // Prevent body scroll
    document.body.style.overflow = 'hidden';
}

function closeFullscreen() {
    const overlay = document.getElementById('fullscreen-overlay');
    if (overlay) {
        overlay.remove();
    }

    // Remove keyboard listener
    document.removeEventListener('keydown', handleFullscreenKeys);

    // Restore body scroll
    document.body.style.overflow = '';
}

function handleFullscreenKeys(e) {
    if (e.key === 'Escape') {
        closeFullscreen();
    }
}

function scaleAnimationsForFullscreen(element) {
    const elementId = element.id.replace('-fullscreen', '');

    // Create specific scaling for each animation type
    const style = document.createElement('style');

    // Base scaling for all elements
    let scaleCSS = `
        #${element.id} {
            width: 100% !important;
            height: 100% !important;
            display: flex !important;
            align-items: center !important;
            justify-content: center !important;
        }
    `;

    // Specific scaling based on animation type
    switch (elementId) {
        case 'text-overlays':
            scaleCSS += `
                #${element.id} {
                    flex-direction: column !important;
                    gap: 40px !important;
                }
                #${element.id} .text-overlay {
                    font-size: 4rem !important;
                    padding: 30px 60px !important;
                    margin: 0 !important;
                    border-radius: 50px !important;
                    min-width: 800px !important;
                    text-align: center !important;
                }
                #${element.id} .text-overlay.solution {
                    font-size: 5rem !important;
                }
            `;
            break;

        case 'logo-intro':
            scaleCSS += `
                #${element.id} {
                    flex-direction: column !important;
                    gap: 60px !important;
                }
                #${element.id} .bitflow-logo {
                    gap: 40px !important;
                }
                #${element.id} .logo-text {
                    font-size: 8rem !important;
                }
                #${element.id} .logo-wave {
                    font-size: 8rem !important;
                }
                #${element.id} .tagline {
                    font-size: 3rem !important;
                    text-align: center !important;
                }
            `;
            break;

        case 'defi-diagram':
            scaleCSS += `
                #${element.id} {
                    flex-direction: column !important;
                    gap: 80px !important;
                }
                #${element.id} .step-box {
                    font-size: 3rem !important;
                    padding: 40px 80px !important;
                    border-radius: 20px !important;
                    min-width: 500px !important;
                    text-align: center !important;
                }
                #${element.id} .arrow {
                    font-size: 6rem !important;
                    margin: 20px 0 !important;
                }
            `;
            break;

        case 'partner-logos':
            scaleCSS += `
                #${element.id} {
                    justify-content: space-around !important;
                    padding: 0 100px !important;
                }
                #${element.id} .logo-placeholder {
                    font-size: 4rem !important;
                    padding: 60px 120px !important;
                    border-radius: 20px !important;
                    min-width: 300px !important;
                    text-align: center !important;
                }
            `;
            break;

        case 'use-cases':
            scaleCSS += `
                #${element.id} {
                    display: grid !important;
                    grid-template-columns: 1fr 1fr !important;
                    gap: 100px !important;
                    padding: 100px !important;
                }
                #${element.id} .use-case {
                    display: flex !important;
                    flex-direction: column !important;
                    align-items: center !important;
                    gap: 30px !important;
                }
                #${element.id} .case-icon {
                    font-size: 8rem !important;
                }
                #${element.id} .case-text {
                    font-size: 2.5rem !important;
                    text-align: center !important;
                    font-weight: 600 !important;
                }
            `;
            break;

        case 'final-slate':
            scaleCSS += `
                #${element.id} {
                    flex-direction: column !important;
                    gap: 60px !important;
                    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%) !important;
                    color: white !important;
                }
                #${element.id} .final-logo {
                    gap: 40px !important;
                }
                #${element.id} .final-text {
                    font-size: 10rem !important;
                }
                #${element.id} .final-wave {
                    font-size: 10rem !important;
                }
                #${element.id} .final-tagline {
                    font-size: 4rem !important;
                    text-align: center !important;
                }
                #${element.id} .final-starknet {
                    font-size: 2.5rem !important;
                    opacity: 0.8 !important;
                }
            `;
            break;

        default:
            // Default scaling for bitcoin-animation, icons-animation, data-stream
            scaleCSS += `
                #${element.id} .bitcoin-logo,
                #${element.id} .transaction-arrow,
                #${element.id} .destination {
                    font-size: 8rem !important;
                }
                #${element.id} .icon {
                    font-size: 6rem !important;
                }
                #${element.id} .endpoint {
                    font-size: 2.5rem !important;
                    padding: 30px 60px !important;
                }
                #${element.id} .packet {
                    width: 40px !important;
                    height: 40px !important;
                }
            `;
    }

    style.textContent = scaleCSS;
    document.head.appendChild(style);

    // Remove style when fullscreen closes
    const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
            if (mutation.type === 'childList') {
                mutation.removedNodes.forEach((node) => {
                    if (node.id === 'fullscreen-overlay') {
                        style.remove();
                        observer.disconnect();
                    }
                });
            }
        });
    });

    observer.observe(document.body, { childList: true });
}

// Simple slideshow - just cycles through all visuals
function viewAllFullscreen() {
    const animations = [
        'bitcoin-animation',
        'text-overlays',
        'icons-animation',
        'logo-intro',
        'data-stream',
        'defi-diagram',
        'partner-logos',
        'use-cases',
        'final-slate'
    ];

    let currentIndex = 0;

    function showNext() {
        if (currentIndex >= animations.length) {
            return; // End slideshow
        }

        viewFullscreen(animations[currentIndex]);
        currentIndex++;

        // Auto-advance after 8 seconds
        setTimeout(() => {
            closeFullscreen();
            setTimeout(showNext, 300);
        }, 8000);
    }

    showNext();
}

// Enhanced animation controls
function restartAnimation(elementId) {
    const element = document.getElementById(elementId);
    if (element) {
        // Remove and re-add animation classes to restart
        const animatedElements = element.querySelectorAll('[class*="animation"], [class*="slide"], [class*="fade"], [class*="bounce"], [class*="pulse"]');

        animatedElements.forEach(el => {
            const classes = el.className;
            el.className = '';
            setTimeout(() => {
                el.className = classes;
            }, 10);
        });
    }
}

// Auto-restart animations every 15 seconds for continuous demo
function startAutoRestart() {
    const animationIds = [
        'bitcoin-animation',
        'text-overlays',
        'icons-animation',
        'logo-intro',
        'data-stream',
        'defi-diagram',
        'partner-logos',
        'use-cases',
        'final-slate'
    ];

    animationIds.forEach(id => {
        setInterval(() => {
            restartAnimation(id);
        }, 15000 + Math.random() * 5000); // Stagger restarts
    });
}

// Initialize when page loads
document.addEventListener('DOMContentLoaded', function () {
    // Start auto-restart for continuous demo
    startAutoRestart();

    // Add click handlers to restart animations
    document.querySelectorAll('.animation-container').forEach(container => {
        container.addEventListener('click', () => {
            restartAnimation(container.id);
        });
    });

    // Add keyboard shortcuts
    document.addEventListener('keydown', function (e) {
        if (e.ctrlKey || e.metaKey) {
            switch (e.key) {
                case 'd':
                    e.preventDefault();
                    downloadAllAnimations();
                    break;
                case 'r':
                    e.preventDefault();
                    location.reload();
                    break;
            }
        }
    });

    // Show instructions
    console.log('BitFlow Demo Visuals Ready!');
    console.log('- Click any animation to restart it');
    console.log('- Use Ctrl+D to download all PNGs');
    console.log('- Use Ctrl+R to refresh the page');
    console.log('- Animations auto-restart every 15 seconds');
});

// Utility function to create video-ready content
function optimizeForVideo() {
    // Ensure all animations are smooth and video-ready
    document.body.style.transform = 'translateZ(0)'; // Force hardware acceleration

    // Set high contrast for better video quality
    document.documentElement.style.setProperty('--high-contrast', 'true');
}

// Call optimization
optimizeForVideo();

// Export functions for external use
window.BitFlowVisuals = {
    downloadAnimation,
    downloadAllAnimations,
    restartAnimation,
    viewFullscreen,
    viewAllFullscreen,
    closeFullscreen,
    recorder
};

// End of script.js - Clean and functional
