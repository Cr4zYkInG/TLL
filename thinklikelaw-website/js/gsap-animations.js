/**
 * gsap-animations.js — Lightweight scroll reveal system
 * Ported from Theme Inspiration GSAPWrapper.js
 * Performance-optimised: no heavy parallax, GPU-composited transforms only
 */

(function () {
  'use strict';

  function initGSAP() {
    if (typeof gsap === 'undefined' || typeof ScrollTrigger === 'undefined') {
      setTimeout(initGSAP, 100);
      return;
    }

    gsap.registerPlugin(ScrollTrigger);

    // Use defaults for better performance
    gsap.defaults({ ease: 'power3.out', duration: 0.7 });

    /* ─────────────────────────────────────────────
       1. HERO ENTRY ANIMATION  (one-shot timeline)
       Targets individual children, not wrapper divs
    ───────────────────────────────────────────── */
    const tl = gsap.timeline({ delay: 0.3 });

    const heroElements = [
      { sel: '.hero-badge',     y: 20 },
      { sel: '.mode-toggle',    y: 20 },
      { sel: '.hero-title',     y: 30 },
      { sel: '.hero-sub',       y: 20 },
      { sel: '.hero-cta-group', y: 20 },
      { sel: '.hero-visual',    y: 30 },
    ];

    heroElements.forEach(function (item, i) {
      const el = document.querySelector(item.sel);
      if (!el) return;
      tl.fromTo(
        el,
        { y: item.y, opacity: 0 },
        { y: 0, opacity: 1, duration: 0.55, ease: 'power2.out' },
        i === 0 ? 0 : '>-0.35'
      );
    });

    /* ─────────────────────────────────────────────
       2. SECTION SCROLL-REVEAL  (.animate class)
       Simple fade-up / slide-from-sides
       Skips hero children already animated above
    ───────────────────────────────────────────── */
    const animateEls = document.querySelectorAll('.animate');

    animateEls.forEach(function (el) {
      // Skip elements inside the hero section (handled by timeline above)
      if (el.closest('.hero-section, .hero-bg-wrapper')) return;

      var fromX = 0, fromY = 60;
      if (el.classList.contains('from-left'))  { fromX = -70; fromY = 0; }
      if (el.classList.contains('from-right')) { fromX =  70; fromY = 0; }

      gsap.fromTo(
        el,
        { x: fromX, y: fromY, opacity: 0 },
        {
          x: 0, y: 0, opacity: 1,
          scrollTrigger: {
            trigger: el,
            start: 'top 90%',
            once: true,
          },
        }
      );
    });

    /* ─────────────────────────────────────────────
       3. STAGGERED GRID CARDS
    ───────────────────────────────────────────── */
    var grids = [
      '.lab-features-grid',
      '.process-grid',
      '.pricing-grid',
      '.resources-grid',
    ];

    grids.forEach(function (sel) {
      var container = document.querySelector(sel);
      if (!container) return;
      var cards = container.children;
      if (!cards.length) return;

      gsap.fromTo(
        Array.from(cards),
        { y: 40, opacity: 0 },
        {
          y: 0, opacity: 1,
          duration: 0.55,
          stagger: 0.1,
          scrollTrigger: {
            trigger: container,
            start: 'top 88%',
            once: true,
          },
        }
      );
    });

    /* ─────────────────────────────────────────────
       4. SECTION TITLE UNDERLINE BARS
    ───────────────────────────────────────────── */
    gsap.utils.toArray('.section-title').forEach(function (title) {
      ScrollTrigger.create({
        trigger: title,
        start: 'top 88%',
        once: true,
        onEnter: function () {
          title.classList.add('title-revealed');
        },
      });
    });

    /* ─────────────────────────────────────────────
       5. ROADMAP ITEMS  (stagger from left)
    ───────────────────────────────────────────── */
    var roadmapItems = document.querySelectorAll('.roadmap-item');
    if (roadmapItems.length) {
      gsap.fromTo(
        Array.from(roadmapItems),
        { x: -40, opacity: 0 },
        {
          x: 0, opacity: 1,
          duration: 0.55,
          stagger: 0.12,
          scrollTrigger: {
            trigger: '.roadmap-timeline',
            start: 'top 88%',
            once: true,
          },
        }
      );
    }

    /* ─────────────────────────────────────────────
       6. PROMPT CARDS  (stagger from right)
    ───────────────────────────────────────────── */
    var promptCards = document.querySelectorAll('.prompt-card');
    if (promptCards.length) {
      gsap.fromTo(
        Array.from(promptCards),
        { x: 50, opacity: 0 },
        {
          x: 0, opacity: 1,
          duration: 0.55,
          stagger: 0.1,
          scrollTrigger: {
            trigger: '.prompt-slider-container',
            start: 'top 90%',
            once: true,
          },
        }
      );
    }

    /* ─────────────────────────────────────────────
       7. FAQ ITEMS  (subtle stagger fade)
    ───────────────────────────────────────────── */
    var faqItems = document.querySelectorAll('.faq-accordion-item');
    if (faqItems.length) {
      gsap.fromTo(
        Array.from(faqItems),
        { y: 16, opacity: 0 },
        {
          y: 0, opacity: 1,
          duration: 0.4,
          stagger: 0.06,
          scrollTrigger: {
            trigger: '.faq-accordion',
            start: 'top 90%',
            once: true,
          },
        }
      );
    }

    /* ─────────────────────────────────────────────
       8. CTA SECTION  (scale + fade)
    ───────────────────────────────────────────── */
    var ctaSection = document.querySelector('.cta-section');
    if (ctaSection) {
      gsap.fromTo(
        ctaSection,
        { scale: 0.98, opacity: 0 },
        {
          scale: 1, opacity: 1, duration: 0.6,
          scrollTrigger: {
            trigger: ctaSection,
            start: 'top 90%',
            once: true,
          },
        }
      );
    }

    /* ─────────────────────────────────────────────
       9. FLOATING CIRCLES  (lightweight CSS parallax via transform)
       Only runs on non-mobile to avoid lag
    ───────────────────────────────────────────── */
    if (window.innerWidth > 768) {
      var circles = document.querySelectorAll('.theme-circle');
      circles.forEach(function (circle, i) {
        var speed = 0.15 + (i % 3) * 0.08;
        gsap.to(circle, {
          y: -80 * speed,
          ease: 'none',
          scrollTrigger: {
            trigger: '.hero-bg-wrapper',
            start: 'top top',
            end: 'bottom top',
            scrub: 1.5,  // smooth scrub, avoids jank
          },
        });
      });
    }

    // Refresh after all images/fonts load
    window.addEventListener('load', function () {
      ScrollTrigger.refresh();
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', initGSAP);
  } else {
    initGSAP();
  }
})();
