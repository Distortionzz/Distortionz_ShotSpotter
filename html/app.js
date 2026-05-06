(function () {
    const stack    = document.getElementById('dispatchStack');
    const template = document.getElementById('dispatchCardTemplate');
    const cards    = {}; // incidentId -> { el, totalSec, secondsLeft }

    function formatTime(sec) {
        if (sec < 0) sec = 0;
        const m = Math.floor(sec / 60);
        const s = sec % 60;
        return `${m}:${s.toString().padStart(2, '0')}`;
    }

    function applyTimer(card, sec, totalSec) {
        const t = card.querySelector('.card-timer');
        const fill = card.querySelector('.card-progress-fill');
        t.textContent = formatTime(sec);
        t.classList.remove('warn', 'critical');
        if (sec <= 5)       t.classList.add('critical');
        else if (sec <= 12) t.classList.add('warn');

        if (fill) {
            const pct = totalSec > 0 ? (sec / totalSec) * 100 : 0;
            fill.style.width = pct + '%';
            fill.classList.toggle('warn', sec <= 12 && sec > 5);
        }
    }

    function applyWeaponPill(card, label, weaponClass) {
        const pill = card.querySelector('.weapon-pill');
        pill.textContent = (label || 'FIREARM').toUpperCase();
        pill.classList.remove('pistol', 'smg', 'rifle', 'shotgun', 'sniper', 'heavy');
        if (weaponClass) pill.classList.add(weaponClass);
    }

    function applyShotCount(card, count, bump) {
        const v = card.querySelector('.counter-value');
        v.textContent = count;
        if (bump) {
            v.classList.remove('bumped');
            // restart animation
            void v.offsetWidth;
            v.classList.add('bumped');
        }
    }

    function createCard(data) {
        const node = template.content.firstElementChild.cloneNode(true);
        node.dataset.incidentId = data.id;
        node.querySelector('.street').textContent   = data.streetName || 'Unknown area';
        node.querySelector('.zone').textContent     = data.zoneName   || '—';
        node.querySelector('.distance').textContent = '—';
        applyWeaponPill(node, data.weaponLabel, data.weaponClass);
        applyShotCount(node, data.shotCount || 1, false);
        applyTimer(node, data.durationSec, data.durationSec);
        stack.appendChild(node);
        return node;
    }

    function removeCard(id) {
        const entry = cards[id];
        if (!entry) return;
        entry.el.classList.add('fading');
        setTimeout(() => {
            if (entry.el && entry.el.parentNode) entry.el.parentNode.removeChild(entry.el);
            delete cards[id];
        }, 400);
    }

    function clearAll() {
        Object.keys(cards).forEach(removeCard);
    }

    window.addEventListener('message', function (event) {
        const data = event.data || {};
        const action = data.action;

        if (action === 'show') {
            // If it already exists (rare) — treat as update
            if (cards[data.id]) {
                applyShotCount(cards[data.id].el, data.shotCount, true);
                applyWeaponPill(cards[data.id].el, data.weaponLabel, data.weaponClass);
                cards[data.id].secondsLeft = data.durationSec;
                cards[data.id].totalSec    = data.durationSec;
                applyTimer(cards[data.id].el, data.durationSec, data.durationSec);
                return;
            }
            const el = createCard(data);
            cards[data.id] = {
                el:          el,
                totalSec:    data.durationSec,
                secondsLeft: data.durationSec,
            };
        }

        if (action === 'update') {
            const entry = cards[data.id];
            if (!entry) return;
            if (typeof data.shotCount === 'number') {
                applyShotCount(entry.el, data.shotCount, true);
            }
            if (data.weaponLabel) {
                applyWeaponPill(entry.el, data.weaponLabel, data.weaponClass);
            }
            // Reset timer on update (new shot in cluster = fresh 30s)
            entry.secondsLeft = entry.totalSec;
            applyTimer(entry.el, entry.totalSec, entry.totalSec);
        }

        if (action === 'tick') {
            const entry = cards[data.id];
            if (!entry) return;
            if (typeof data.distanceM === 'number') {
                entry.el.querySelector('.distance').textContent = data.distanceM + ' m';
            }
            if (typeof data.secondsLeft === 'number') {
                entry.secondsLeft = data.secondsLeft;
                applyTimer(entry.el, data.secondsLeft, entry.totalSec);
            }
        }

        if (action === 'hide') {
            removeCard(data.id);
        }

        if (action === 'hideAll') {
            clearAll();
        }
    });
})();
