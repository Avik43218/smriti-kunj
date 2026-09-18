import React from 'react';
import warliDark from '../assets/backgrounds/warli-dark.svg';
import warliLight from '../assets/backgrounds/warli-light.svg';

export const MotifBackground = () => {
  return (
    <div
      aria-hidden="true"
      className="fixed inset-0 pointer-events-none z-0 select-none overflow-hidden"
    >
      {/* Light Mode Layer: Traditional Warm Terracotta Warli Folk Art Pattern */}
      <div
        className="absolute inset-0 bg-repeat dark:hidden transition-opacity duration-300"
        style={{
          backgroundImage: `url(${warliLight})`,
          backgroundSize: '760px 570px',
          opacity: 0.18,
        }}
      />

      {/* Dark Mode Layer: Traditional Luminous Ivory & Gold Warli Folk Art Pattern */}
      <div
        className="absolute inset-0 bg-repeat hidden dark:block transition-opacity duration-300"
        style={{
          backgroundImage: `url(${warliDark})`,
          backgroundSize: '760px 570px',
          opacity: 0.24,
        }}
      />
    </div>
  );
};

export default MotifBackground;
