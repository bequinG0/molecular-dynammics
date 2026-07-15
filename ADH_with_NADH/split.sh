#!/bin/bash
# ============================================
# split_complex.sh
# Разделение holo-структуры 1MG5 на белок и NADH
# Вход: 1mg5.cif
# Выход: 1MG5_protein.pdb, nadh.pdb
# ============================================

set -e  # Выход при ошибке

echo "=========================================="
echo "  РАЗДЕЛЕНИЕ КОМПЛЕКСА 1MG5"
echo "=========================================="

# Шаг 1: Конвертация CIF → PDB
echo ""
echo "[1/4] Конвертация CIF → PDB..."
if [ ! -f "1mg5.pdb" ]; then
    gmx editconf -f 1mg5.cif -o 1mg5.pdb 2>&1 | tail -1
    echo "  ✓ 1mg5.pdb создан"
else
    echo "  ✓ 1mg5.pdb уже существует"
fi

# Шаг 2: Анализ содержимого
echo ""
echo "[2/4] Анализ содержимого..."
echo "  Лиганды в структуре:"
grep "HETATM" 1mg5.pdb | awk '{print $4}' | sort -u | while read lig; do
    count=$(grep -c "HETATM.*$lig" 1mg5.pdb)
    echo "    - $lig ($count атомов)"
done

echo ""
echo "  Цепи белка:"
grep "^ATOM" 1mg5.pdb | awk '{print $5}' | sort -u | while read chain; do
    count=$(grep -c "^ATOM.* $chain " 1mg5.pdb)
    echo "    - Цепь $chain ($count атомов)"
done

echo ""
echo "  Цепи NADH:"
grep "NAI" 1mg5.pdb | awk '{print $5}' | sort -u | while read chain; do
    count=$(grep -c "NAI.* $chain " 1mg5.pdb)
    echo "    - NAI цепь $chain ($count атомов)"
done

# Шаг 3: Извлечение
echo ""
echo "[3/4] Извлечение белка (цепь A) и NADH (цепь D)..."

# Белок — цепь A
grep "^ATOM.* A " 1mg5.pdb > 1MG5_protein.pdb
protein_atoms=$(wc -l < 1MG5_protein.pdb)
echo "  ✓ Белок (цепь A): $protein_atoms атомов → 1MG5_protein.pdb"

# NADH — цепь D
grep "^HETATM.*NAI.* D " 1mg5.pdb > nadh.pdb
nadh_atoms=$(wc -l < nadh.pdb)
echo "  ✓ NADH (цепь D): $nadh_atoms атомов → nadh.pdb"

# Шаг 4: Проверки
echo ""
echo "[4/4] Проверки..."

# Проверка 1: Число атомов NADH (должно быть 44 для полного NADH без H)
if [ "$nadh_atoms" -eq 44 ]; then
    echo "  ✓ NADH: 44 атома — полный, без водородов (норма для рентгена)"
elif [ "$nadh_atoms" -eq 48 ]; then
    echo "  ✓ NADH: 48 атомов — полный, включая фосфатные кислороды"
elif [ "$nadh_atoms" -gt 0 ] && [ "$nadh_atoms" -lt 50 ]; then
    echo "  ⚠ NADH: $nadh_atoms атомов — нестандартное число, проверь визуально"
else
    echo "  ✗ NADH: $nadh_atoms атомов — что-то не так!"
    exit 1
fi

# Проверка 2: В белке нет HETATM
if grep -q "HETATM" 1MG5_protein.pdb; then
    echo "  ✗ Белок содержит HETATM! Проверь файл."
    exit 1
else
    echo "  ✓ Белок: только ATOM (нет лигандов)"
fi

# Проверка 3: В NADH только NAI
other=$(grep -v "NAI" nadh.pdb | head -1)
if [ -z "$other" ]; then
    echo "  ✓ NADH: только NAI (нет других лигандов)"
else
    echo "  ✗ NADH содержит другие остатки!"
    exit 1
fi

# Проверка 4: Число цепей в белке
chains=$(grep "^ATOM" 1MG5_protein.pdb | awk '{print $5}' | sort -u | wc -l)
if [ "$chains" -eq 1 ]; then
    echo "  ✓ Белок: одна цепь (A)"
else
    echo "  ⚠ Белок: $chains цепей — возможно, осталась цепь B"
fi

# Проверка 5: Есть ли ацетат (должен быть, но мы его не берём)
act_count=$(grep -c "ACT" 1mg5.pdb || true)
if [ "$act_count" -gt 0 ]; then
    echo "  ℹ Ацетат (ACT): $act_count атомов — не извлечён (мы его не берём)"
fi

echo ""
echo "=========================================="
echo "  ГОТОВО!"
echo "  Белок: 1MG5_protein.pdb ($protein_atoms атомов)"
echo "  NADH:  nadh.pdb ($nadh_atoms атомов)"
echo "=========================================="
echo ""
echo "Следующие шаги:"
echo "  1. gmx pdb2gmx -f 1MG5_protein.pdb -o protein.gro -water tip3p -ff charmm27"
echo "  2. Загрузить nadh.pdb на https://cgenff.umaryland.edu/"
echo ""
