# Белок (цепь A, только ATOM)
grep "^ATOM" 1mg5.pdb | awk '$5 == "A"' > 1MG5_protein.pdb

# NADH (HETATM, остаток NAI, цепь A, номер 850)
grep "^HETATM" 1mg5.pdb | awk '$4 == "NAI" && $5 == "A"' > nadh.pdb

# Проверка
echo "=========================================="
echo "  РЕЗУЛЬТАТЫ РАЗДЕЛЕНИЯ"
echo "=========================================="
echo ""
echo "Белок (1MG5_protein.pdb):"
echo "  Атомов: $(wc -l < 1MG5_protein.pdb)"
echo "  Цепь:   A"
echo "  Первая строка:"
head -1 1MG5_protein.pdb
echo "  Последняя строка:"
tail -1 1MG5_protein.pdb
echo ""
echo "NADH (nadh.pdb):"
echo "  Атомов: $(wc -l < nadh.pdb)"
echo "  Цепь:   A"
echo "  Первая строка:"
head -1 nadh.pdb
echo "  Последняя строка:"
tail -1 nadh.pdb
echo ""
echo "=========================================="
