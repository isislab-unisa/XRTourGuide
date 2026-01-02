(function() {
    'use strict';
    
    const originalDismiss = window.dismissAddRelatedObjectPopup;
    
    window.dismissAddRelatedObjectPopup = function(win, newId, newRepr) {
        if (originalDismiss) {
            originalDismiss(win, newId, newRepr);
        }
        
        const selectField = document.getElementById('id_sub_tours');
        if (selectField && newId) {
            addNewSubtourToList(newId, newRepr);
        }
    };
    
    function addNewSubtourToList(id, label) {
        const container = document.getElementById('id_sub_tours');
        if (!container) return;
        
        const li = document.createElement('li');
        
        const checkboxId = `id_sub_tours_${id}`;
        const checkbox = document.createElement('input');
        checkbox.type = 'checkbox';
        checkbox.name = 'sub_tours';
        checkbox.value = id;
        checkbox.id = checkboxId;
        checkbox.checked = true;
        
        const labelEl = document.createElement('label');
        labelEl.htmlFor = checkboxId;
        
        const textSpan = document.createElement('span');
        textSpan.textContent = label.replace(/✏️.*$/, '').trim();
        
        const editLink = document.createElement('a');
        editLink.href = `/admin/xr_tour_guide_core/tour/${id}/change/`;
        editLink.target = '_blank';
        editLink.innerHTML = '✏️ Edit';
        editLink.onclick = function(e) {
            e.stopPropagation();
        };
        
        labelEl.appendChild(checkbox);
        labelEl.appendChild(textSpan);
        labelEl.appendChild(editLink);
        li.appendChild(labelEl);
        
        container.appendChild(li);
        
        li.style.animation = 'highlightNew 2s ease';
        
        showNotification('Sub-tour created and added!', 'success');
    }
    
    function showNotification(message, type = 'success') {
        const notification = document.createElement('div');
        notification.className = 'subtour-notification';
        notification.style.cssText = `
            position: fixed;
            top: 20px;
            right: 20px;
            padding: 16px 24px;
            background: ${type === 'success' ? '#10b981' : '#3b82f6'};
            color: white;
            border-radius: 8px;
            box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1);
            z-index: 9999;
            animation: slideInRight 0.3s ease;
            font-size: 14px;
            font-weight: 500;
        `;
        notification.textContent = message;
        
        document.body.appendChild(notification);
        
        setTimeout(() => {
            notification.style.animation = 'slideOutRight 0.3s ease';
            setTimeout(() => notification.remove(), 300);
        }, 3000);
    }
    
    const style = document.createElement('style');
    style.textContent = `
        @keyframes highlightNew {
            0%, 100% { background: inherit; }
            10%, 30% { background: light-dark(#dbeafe, #1e3a8a); }
        }
        
        @keyframes slideInRight {
            from {
                transform: translateX(100%);
                opacity: 0;
            }
            to {
                transform: translateX(0);
                opacity: 1;
            }
        }
        
        @keyframes slideOutRight {
            from {
                transform: translateX(0);
                opacity: 1;
            }
            to {
                transform: translateX(100%);
                opacity: 0;
            }
        }
    `;
    document.head.appendChild(style);
    
})();