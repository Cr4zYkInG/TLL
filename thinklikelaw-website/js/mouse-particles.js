/**
 * Mouse-Following Particle Effect
 * Inspired by Google Antigravity
 */

(function () {
    let particles = [];
    let canvas, ctx;
    let mouseX = 0, mouseY = 0;
    let colors = ['#95A5A6', '#A569BD', '#EC7063', '#48C9B0', '#F39C12']; // Grey, Purple, Pink, Teal, Orange

    function init() {
        canvas = document.getElementById('particle-canvas');
        if (!canvas) return;

        ctx = canvas.getContext('2d');
        resizeCanvas();

        window.addEventListener('resize', resizeCanvas);
        document.addEventListener('mousemove', handleMouseMove);

        animate();
    }

    function resizeCanvas() {
        canvas.width = window.innerWidth;
        canvas.height = window.innerHeight;
    }

    function handleMouseMove(e) {
        mouseX = e.clientX;
        mouseY = e.clientY;

        // Spawn particles at mouse position
        if (particles.length < 100) { // Limit max particles
            createParticle(mouseX, mouseY);
        }
    }

    function createParticle(x, y) {
        const particle = {
            x: x,
            y: y,
            vx: (Math.random() - 0.5) * 2, // Random horizontal velocity
            vy: (Math.random() - 0.5) * 2, // Random vertical velocity
            size: Math.random() * 4 + 2, // Random size 2-6px
            color: colors[Math.floor(Math.random() * colors.length)],
            alpha: 1, // Start fully opaque
            decay: Math.random() * 0.02 + 0.01 // Fade speed
        };

        particles.push(particle);
    }

    function animate() {
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        // Update and draw particles
        particles = particles.filter(particle => {
            // Update position
            particle.x += particle.vx;
            particle.y += particle.vy;

            // Fade out
            particle.alpha -= particle.decay;

            // Draw particle
            if (particle.alpha > 0) {
                ctx.save();
                ctx.globalAlpha = particle.alpha;
                ctx.fillStyle = particle.color;
                ctx.beginPath();
                ctx.arc(particle.x, particle.y, particle.size, 0, Math.PI * 2);
                ctx.fill();
                ctx.restore();

                return true; // Keep particle
            }

            return false; // Remove particle
        });

        requestAnimationFrame(animate);
    }

    // Auto-initialize when DOM is ready
    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
})();
