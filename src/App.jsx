import './App.css';

const links = [
  { href: 'https://kikikari.github.io/OpenClaw/', label: 'GitHub Pages Dokumentation' },
  { href: 'https://github.com/KikiKari/OpenClaw', label: 'Repository' },
  { href: 'https://github.com/KikiKari/OpenClaw/tree/main', label: 'main-Branch' },
];

function App() {
  return (
    <main className="page-shell">
      <section className="hero-card" aria-labelledby="openclaw-title">
        <p className="eyebrow">OpenClaw</p>
        <h1 id="openclaw-title">Gateway, Dokumentation und Projektoberflächen an einem Ort.</h1>
        <p className="lead">
          Diese Vercel-Produktion zeigt nicht mehr das Codespaces-Template, sondern die
          verbundene OpenClaw-Startseite für Repository, Dokumentation und Frontend-Branch.
        </p>
        <div className="link-grid" aria-label="OpenClaw Ziele">
          {links.map((link) => (
            <a key={link.href} href={link.href} target="_blank" rel="noreferrer">
              {link.label}
              <span aria-hidden="true">↗</span>
            </a>
          ))}
        </div>
      </section>
    </main>
  );
}

export default App;
