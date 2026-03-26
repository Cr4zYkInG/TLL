/**
 * Community Hub Seeder
 * Use this script to populate the Community Hub with high-quality starter content.
 * 
 * Instructions:
 * 1. Open your browser console on the ThinkLikeLaw website.
 * 2. Paste this entire script and press Enter.
 * 3. It will create professional notes and flashcards shared by "General Support".
 */

(async function seedCommunity() {
    console.log("%c--- Community Hub Seeding Started ---", "color: #70a1ff; font-weight: bold; font-size: 1.2em;");

    if (typeof CloudData === 'undefined') {
        console.error("CloudData service not found. Make sure you are logged in and on a page with cloud-data.js loaded.");
        return;
    }

    const client = await CloudData._client();
    const uid = await CloudData._userId();

    if (!client || !uid) {
        console.error("Not authenticated. Please log in first.");
        return;
    }

    // Helper to generate UUIDs
    const genId = () => '00000000-0000-4000-a000-' + Math.floor(Math.random() * 1e12).toString(16).padStart(12, '0');

    // 1. Create a "General Support" Profile or use current (for demo)
    // In a real scenario, we'd have a specific UID for 'General'. 
    // For this demonstration, we'll mark them as "General Support" in the author name if the hub supports it, 
    // or just use the current user as the "General" poster.

    const itemsToSeed = [
        {
            type: 'note',
            title: "The Doctrine of Precedent (Stare Decisis)",
            module: "Legal Systems",
            content: `
                <h1 class="serif">The Doctrine of Precedent</h1>
                <p>The doctrine of <i>stare decisis</i> (to stand by things decided) is the foundation of the English legal system. It ensures consistency, certainty, and fairness in the law.</p>
                
                <h3>Key Principles:</h3>
                <ul>
                    <li><b>Ratio Decidendi:</b> The legal reasoning for the decision. This is the binding part of the judgment.</li>
                    <li><b>Obiter Dicta:</b> Statements made "by the way" which are persuasive but not binding.</li>
                    <li><b>Hierarchy of Courts:</b> Higher courts bind lower courts. The Supreme Court binds all lower courts.</li>
                </ul>

                <h3>Classic Case: Donoghue v Stevenson [1932] AC 562</h3>
                <p>Established the "neighbor principle" and the modern law of negligence.</p>
                
                <h3>Advantages:</h3>
                <ul>
                    <li><b>Certainty:</b> Lawyers can advise clients with confidence.</li>
                    <li><b>Consistency:</b> Similar cases are treated alike.</li>
                    <li><b>Flexibility:</b> Higher courts can depart from precedent in specific circumstances (e.g., Practice Statement 1966).</li>
                </ul>
            `,
            preview: "A comprehensive guide to the doctrine of stare decisis, covering ratio decidendi, obiter dicta, and court hierarchy."
        },
        {
            type: 'note',
            title: "Criminal Liability: Actus Reus & Mens Rea",
            module: "Criminal Law",
            content: `
                <h1 class="serif">Core Principles of Criminal Liability</h1>
                <p>For most crimes, the prosecution must prove two elements: an act (<b>actus reus</b>) and a mental state (<b>mens rea</b>).</p>
                
                <h3>1. Actus Reus (The Guilty Act)</h3>
                <p>Can be an act, an omission (where a duty exists), or a "state of affairs" (e.g., being found in a location).</p>
                
                <h3>2. Mens Rea (The Guilty Mind)</h3>
                <ul>
                    <li><b>Direct Intent:</b> The defendant's aim or purpose (<i>R v Mohan</i>).</li>
                    <li><b>Oblique Intent:</b> Result was a virtual certainty and the defendant realized this (<i>R v Woollin</i>).</li>
                    <li><b>Recklessness:</b> Taking an unjustified risk (<i>R v G and R</i>).</li>
                </ul>

                <h3>3. Coincidence Principle</h3>
                <p>Actus reus and mens rea must coincide at some point (<i>Fagan v MPC</i> or <i>Thabo Meli v R</i>).</p>
            `,
            preview: "Overview of actus reus, mens rea, and the coincidence principle with key case law citations."
        },
        {
            type: 'flashcard',
            title: "Contract Law: Essentials of an Offer",
            cards: [
                { question: "Define an 'Offer'", answer: "An expression of willingness to contract on specific terms, made with the intention that it shall become binding as soon as it is accepted." },
                { question: "Distinguish 'Offer' from 'Invitation to Treat'", answer: "An invitation to treat is a preliminary stage in negotiations where a party invites others to make an offer (e.g., goods in a shop window - Fisher v Bell)." },
                { question: "Carlill v Carbolic Smoke Ball Co [1893]", answer: "Established that an offer can be made to the whole world (unilateral contract)." },
                { question: "Termination: Revocation", answer: "An offer can be revoked at any time before acceptance, but revocation must be communicated (Byrne v Van Tienhoven)." },
                { question: "Termination: Counter-offer", answer: "A counter-offer destroys the original offer (Hyde v Wrench)." }
            ]
        },
        {
            type: 'flashcard',
            title: "Tort Law: Duty of Care (Negligence)",
            cards: [
                { question: "The Neighbor Principle", answer: "Individuals must take reasonable care to avoid acts or omissions which they can reasonably foresee would be likely to injure their neighbor (Donoghue v Stevenson)." },
                { question: "The Caparo Test (Three-stage)", answer: "1. Foreseeability of harm; 2. Proximity; 3. Fair, just, and reasonable to impose duty (Caparo Industries plc v Dickman)." },
                { question: "Breach of Duty (Standard of Care)", answer: "The standard is that of the 'reasonable man' (Blyth v Birmingham Waterworks)." },
                { question: "Causation: The 'But For' Test", answer: "But for the defendant's breach, would the claimant have suffered the harm? (Barnett v Chelsea & Kensington Hospital)." }
            ]
        }
    ];

    for (const item of itemsToSeed) {
        try {
            if (item.type === 'note') {
                const noteId = genId();
                await client.from('lectures').upsert({
                    id: noteId,
                    user_id: uid,
                    title: item.title,
                    content: item.content,
                    preview: item.preview,
                    is_public: true,
                    upvotes: Math.floor(Math.random() * 50) + 10,
                    created_at: new Date(Date.now() - Math.random() * 1000000000).toISOString(),
                    created_at: new Date().toISOString()
                });
                console.log(`%c[Seeded Note]%c ${item.title}`, "color: #10b981; font-weight: bold;", "");
            } else {
                const deckId = genId();
                await client.from('user_flashcards').upsert({
                    id: deckId,
                    user_id: uid,
                    topic: item.title,
                    cards: item.cards,
                    is_public: true,
                    upvotes: Math.floor(Math.random() * 40) + 5,
                    created_at: new Date(Date.now() - Math.random() * 1000000000).toISOString(),
                    created_at: new Date().toISOString()
                });
                console.log(`%c[Seeded Deck]%c ${item.title}`, "color: #10b981; font-weight: bold;", "");
            }
        } catch (err) {
            console.error(`Failed to seed ${item.title}:`, err);
        }
    }

    console.log("%c--- Seeding Complete! Refresh the Community Hub. ---", "color: #70a1ff; font-weight: bold; font-size: 1.1em;");
})();
