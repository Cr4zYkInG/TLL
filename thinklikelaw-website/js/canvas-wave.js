/**
 * Three.js 3D Wave Plexus Grid
 * High-fidelity, mathematically perfect, anti-aliased wireframe mesh.
 * Completely replicates the Reflow.ai "Ultra-Elite" aesthetic.
 */
document.addEventListener("DOMContentLoaded", () => {
    if (typeof THREE === 'undefined') {
        console.error("Three.js not loaded.");
        return;
    }

    const canvas = document.getElementById("hero-waves");
    if (!canvas) return;

    // ─── SCENE SETUP ───
    const scene = new THREE.Scene();

    // ─── CAMERA ───
    // High Field-of-View creates a dramatic, cinematic perspective 
    const camera = new THREE.PerspectiveCamera(80, window.innerWidth / window.innerHeight, 0.1, 1000);
    camera.position.z = 25;
    camera.position.y = 8; // Looking slightly down onto the grid
    camera.rotation.x = -0.25; // Tilt camera slightly down

    // ─── RENDERER ───
    const renderer = new THREE.WebGLRenderer({ canvas: canvas, alpha: true, antialias: true });
    renderer.setPixelRatio(window.devicePixelRatio); // Crisp high-DPI
    
    function resize() {
        const wrapper = document.querySelector('.hero-bg-wrapper');
        const height = wrapper ? wrapper.offsetHeight : window.innerHeight;
        renderer.setSize(window.innerWidth, height);
        camera.aspect = window.innerWidth / height;
        camera.updateProjectionMatrix();
    }
    window.addEventListener('resize', resize);

    // ─── MESH & MATERIALS ───
    // 50 segments wide/deep (high resolution for buttery smooth waves)
    const geometry = new THREE.PlaneGeometry(120, 100, 50, 45);
    geometry.rotateX(-Math.PI / 2); // Lay flat

    const isDark = document.body.classList.contains('dark-mode');
    
    // Dynamic wireframe material
    const material = new THREE.MeshBasicMaterial({
        color: isDark ? 0xffffff : 0x0a0a0a,
        wireframe: true,
        transparent: true,
        opacity: isDark ? 0.12 : 0.08,
    });

    const plane = new THREE.Mesh(geometry, material);
    
    // Push the grid down so it sits below the text
    plane.position.y = -8; 
    scene.add(plane);

    resize();

    // ─── FOG EFFET ───
    // Fog fades the grid endlessly into the distance
    scene.fog = new THREE.FogExp2(isDark ? 0x0a0a0a : 0xffffff, 0.025);

    // ─── ANIMATION LOOP ───
    const clock = new THREE.Clock();

    function animate() {
        requestAnimationFrame(animate);

        const time = clock.getElapsedTime() * 0.5; // Speed multiplier
        
        // ─── VERTEXT DISPLACEMENT (The "Waves") ───
        const position = geometry.attributes.position;
        for (let i = 0; i < position.count; i++) {
            const x = position.getX(i);
            const z = position.getZ(i);
            
            // Rolling hills effect combining multiple low-frequency sines
            const y = Math.sin(x * 0.1 + time) * 2.5 + Math.cos(z * 0.1 + time * 0.8) * 2.5;
            
            position.setY(i, y);
        }
        
        // Tell Three.js the mesh mutated this frame
        position.needsUpdate = true; 

        // ─── LIVE THEME SWITCHING ───
        const currentIsDark = document.body.classList.contains('dark-mode');
        if (currentIsDark) {
            material.color.setHex(0xffffff);
            material.opacity = 0.12;
            scene.fog.color.setHex(0x0a0a0a); // Dark fog
        } else {
            material.color.setHex(0x0a0a0a);
            material.opacity = 0.08;
            scene.fog.color.setHex(0xffffff); // Light fog
        }

        // Render the frame!
        renderer.render(scene, camera);
    }
    
    animate();
});
