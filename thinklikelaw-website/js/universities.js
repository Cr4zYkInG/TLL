// Consolidated University List & Autocomplete Logic
// Now supports passing custom IDs for flexibility (Onboarding vs Signup)

const UK_UNIVERSITIES = [
    "University of Aberdeen",
    "Abertay University",
    "Aberystwyth University",
    "Anglia Ruskin University (ARU)",
    "Aston University",
    "Bangor University",
    "Bath Spa University",
    "University of Bedfordshire",
    "Birkbeck (University of London)",
    "Birmingham City University",
    "Birmingham Newman University",
    "University of Birmingham",
    "University of Bolton",
    "Bournemouth University",
    "BPP University (Specialist)",
    "University of Bradford",
    "University of Brighton",
    "University of Bristol",
    "Brunel University London",
    "University of Buckingham",
    "Buckinghamshire New University",
    "University of Cambridge",
    "Canterbury Christ Church University",
    "Cardiff University",
    "University of Central Lancashire (UCLan)",
    "University of Chester",
    "University of Chichester",
    "City St George's (University of London)",
    "Coventry University",
    "University of Cumbria",
    "De Montfort University (DMU)",
    "University of Derby",
    "University of Dundee",
    "Durham University",
    "University of East Anglia (UEA)",
    "University of East London (UEL)",
    "Edge Hill University",
    "University of Edinburgh",
    "Edinburgh Napier University",
    "University of Essex",
    "University of Exeter",
    "University of Glasgow",
    "Glasgow Caledonian University",
    "University of Gloucestershire",
    "Goldsmiths (University of London)",
    "University of Greenwich",
    "University of Hertfordshire",
    "University of Hull",
    "Keele University",
    "University of Kent",
    "King's College London (KCL)",
    "Kingston University",
    "Lancaster University",
    "The University of Law (ULaw - Specialist)",
    "University of Leeds",
    "Leeds Beckett University",
    "Leeds Trinity University",
    "University of Leicester",
    "University of Lincoln",
    "University of Liverpool",
    "Liverpool Hope University",
    "Liverpool John Moores University (LJMU)",
    "London Metropolitan University",
    "London School of Economics and Political Science (LSE)",
    "London South Bank University (LSBU)",
    "University of Manchester",
    "Manchester Metropolitan University (MMU)",
    "Middlesex University",
    "Newcastle University",
    "University of Northampton",
    "Northeastern University London",
    "Northumbria University",
    "University of Nottingham",
    "Nottingham Trent University (NTU)",
    "The Open University",
    "University of Oxford",
    "Oxford Brookes University",
    "University of Plymouth",
    "University of Portsmouth",
    "Queen Mary University of London (QMUL)",
    "Queen's University Belfast (QUB)",
    "University of Reading",
    "Robert Gordon University (RGU)",
    "University of Roehampton",
    "Royal Holloway (University of London)",
    "University of Salford",
    "University of Sheffield",
    "Sheffield Hallam University",
    "SOAS University of London",
    "Solent University",
    "University of South Wales",
    "University of Southampton",
    "St Mary's University (Twickenham)",
    "Staffordshire University",
    "University of Stirling",
    "University of Strathclyde",
    "University of Suffolk",
    "University of Sunderland",
    "University of Surrey",
    "University of Sussex",
    "Swansea University",
    "Teesside University",
    "University College London (UCL)",
    "Ulster University",
    "University of Wales Trinity Saint David",
    "University of Warwick",
    "University of West London",
    "University of the West of England (UWE Bristol)",
    "University of the West of Scotland",
    "University of Westminster",
    "University of Winchester",
    "University of Wolverhampton",
    "University of Worcester",
    "University of York",
    "York St John University",
    "Other"
];

function initUniversityAutocomplete(options = {}) {
    // Default IDs if not provided (backward compatibility)
    const config = {
        inputId: options.inputId || 'university-input',
        hiddenId: options.hiddenId || 'university',
        dropdownId: options.dropdownId || 'uni-dropdown',
        customContainerId: options.customContainerId || 'custom-uni-container',
        customInputId: options.customInputId || 'custom-uni'
    };

    const input = document.getElementById(config.inputId);
    const hiddenInput = document.getElementById(config.hiddenId);
    const dropdown = document.getElementById(config.dropdownId);
    const customContainer = document.getElementById(config.customContainerId);
    const customInput = document.getElementById(config.customInputId);

    let highlightedIndex = -1;

    if (!input || !dropdown) {
        console.warn('University Autocomplete: Missing elements', config);
        return;
    }

    // Function to render list
    function renderList(filterText = '') {
        dropdown.innerHTML = '';
        const lowerFilter = filterText.toLowerCase();

        const filtered = UK_UNIVERSITIES.filter(uni =>
            uni.toLowerCase().includes(lowerFilter)
        );

        if (filtered.length === 0) {
            // dropdown.style.display = 'none'; // Optional: hide if no matches
            dropdown.innerHTML = '<div class="uni-option disabled" style="color: var(--text-secondary); cursor: default; padding: 0.7rem 1rem;">No matches found</div>';
            dropdown.style.display = 'block';
            return;
        }

        filtered.forEach(uni => {
            const div = document.createElement('div');
            div.className = 'uni-option';
            div.textContent = uni;

            div.addEventListener('click', () => {
                selectUniversity(uni);
            });

            dropdown.appendChild(div);
        });

        dropdown.style.display = 'block';
    }

    function selectUniversity(uniName) {
        input.value = uniName;
        if (hiddenInput) hiddenInput.value = uniName;
        dropdown.style.display = 'none';

        // Handle "Other"
        if (uniName === 'Other') {
            if (customContainer) {
                customContainer.style.display = 'block';
                if (customInput) {
                    customInput.required = true;
                    customInput.focus();
                }
            }
        } else {
            if (customContainer) {
                customContainer.style.display = 'none';
                if (customInput) {
                    customInput.required = false;
                    customInput.value = '';
                }
            }
        }
    }

    // Event Listeners
    input.addEventListener('input', (e) => {
        renderList(e.target.value);
    });

    input.addEventListener('focus', () => {
        if (input.value.length === 0) renderList('');
        else renderList(input.value);
    });

    // Close when clicking outside
    document.addEventListener('click', (e) => {
        if (!input.contains(e.target) && !dropdown.contains(e.target)) {
            dropdown.style.display = 'none';
        }
    });

    // Keyboard navigation
    input.addEventListener('keydown', (e) => {
        if (dropdown.style.display === 'none') {
            if (e.key === 'ArrowDown') renderList(input.value);
            return;
        }

        const options = dropdown.querySelectorAll('.uni-option:not(.disabled)');

        if (e.key === 'ArrowDown') {
            e.preventDefault();
            if (options.length > 0) {
                highlightedIndex = (highlightedIndex + 1) % options.length;
                updateHighlight(options);
            }
        } else if (e.key === 'ArrowUp') {
            e.preventDefault();
            if (options.length > 0) {
                highlightedIndex = (highlightedIndex - 1 + options.length) % options.length;
                updateHighlight(options);
            }
        } else if (e.key === 'Enter') {
            e.preventDefault();
            if (highlightedIndex >= 0 && options[highlightedIndex]) {
                selectUniversity(options[highlightedIndex].textContent);
            }
        } else if (e.key === 'Escape') {
            dropdown.style.display = 'none';
        }
    });

    function updateHighlight(options) {
        options.forEach(o => o.classList.remove('highlighted'));
        if (options[highlightedIndex]) {
            options[highlightedIndex].classList.add('highlighted');
            options[highlightedIndex].scrollIntoView({ block: 'nearest' });
        }
    }
}
