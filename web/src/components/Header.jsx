import React from 'react';
import { Search, ArrowDownAZ, ArrowUpZA } from 'lucide-react';
import logoImg from '../assets/images/logo-horizontal.png';

export default function Header({ search, setSearch, sortDesc, setSortDesc, categories, selectedCat, setSelectedCat, totalItems }) {
  return (
    <div className="header">
      <div className="logo-row">
        <img src={logoImg} alt="All Rahman Logo" style={{ height: 48, objectFit: 'contain' }} />
      </div>
      
      <div style={{ fontWeight: 'bold', marginBottom: 12 }}>Barang <span style={{ color: '#6B7280', fontWeight: 'normal' }}>({totalItems} Item)</span></div>

      <div className="search-row">
        <div className="search-input-wrapper">
          <Search className="search-icon" size={18} />
          <input 
            type="text" 
            className="search-input" 
            placeholder="Cari..." 
            value={search}
            onChange={e => setSearch(e.target.value)}
          />
        </div>
        <button className="sort-btn" onClick={() => setSortDesc(!sortDesc)}>
          {sortDesc ? <ArrowUpZA size={20} /> : <ArrowDownAZ size={20} />}
        </button>
      </div>

      <div className="pills-container">
        <div 
          className={`pill ${selectedCat === 'Semua' ? 'active' : ''}`}
          onClick={() => setSelectedCat('Semua')}
        >
          Semua
        </div>
        {categories.map(c => (
          <div 
            key={c.id}
            className={`pill ${selectedCat === c.id ? 'active' : ''}`}
            onClick={() => setSelectedCat(c.id)}
          >
            {c.name}
          </div>
        ))}
      </div>
    </div>
  );
}
