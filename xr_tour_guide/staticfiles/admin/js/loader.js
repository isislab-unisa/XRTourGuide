document.addEventListener('DOMContentLoaded', function () {

    const style = document.createElement('style');
    style.textContent = `
        @keyframes spin {
            0% { transform: rotate(0deg); }
            100% { transform: rotate(360deg); }
        }
        @keyframes spin-reverse {
            0% { transform: rotate(360deg); }
            100% { transform: rotate(0deg); }
        }

        .spinner, .spinner-reverse {
            border-radius: 9999px;
            border-style: solid;
            border-color: white;
        }

        .spinner {
            width: 3rem;
            height: 3rem;
            border-width: 4px;
            border-top-color: transparent;
            animation: spin 1s linear infinite;
        }

        .spinner-reverse {
            width: 2rem;
            height: 2rem;
            border-width: 4px;
            border-bottom-color: transparent;
            animation: spin-reverse 1s linear infinite;
        }
    `;
    document.head.appendChild(style);


    const forms = document.querySelectorAll('form');

    forms.forEach(form => {
        form.addEventListener('submit', function (event) {

            if (document.getElementById('loading-overlay')) return;

            event.preventDefault();

            const loader = document.createElement('div');
            loader.id = 'loading-overlay';
            loader.className = `
                fixed inset-0 z-[1000] flex items-center 
                justify-center bg-black/50 backdrop-blur-sm
            `;

            loader.innerHTML = `
                <div class="flex flex-col items-center">

                    <img 
                        id="loading-logo"
                        src="/static/admin/img/XRTOURGUIDE.png"
                        alt="Logo"
                        class="w-24 h-auto mb-6 animate-pulse"
                    />

                    <div class="relative w-16 h-16">
                        <div class="absolute inset-0 flex items-center justify-center">
                            <div class="w-12 h-12 border-4 spinner"></div>
                        </div>
                        <div class="absolute inset-0 flex items-center justify-center">
                            <div class="w-8 h-8 border-4 spinner-reverse"></div>
                        </div>
                    </div>

                    <p class="mt-4 text-white font-medium">Processing...</p>
                </div>
            `;

            document.body.appendChild(loader);

            const logo = document.getElementById('loading-logo');
            logo.onload = () => console.log("LOGO CARICATO CORRETTAMENTE:", logo.src);
            logo.onerror = () => console.error("⚠️ ERRORE NEL CARICAMENTO LOGO:", logo.src);

            setTimeout(() => form.submit(), 300);
        });
    });
});
