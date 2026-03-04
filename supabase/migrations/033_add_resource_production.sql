-- Ressourcen-Produktion pro Stunde (via Clipboard-Parser in der App)
ALTER TABLE villages ADD COLUMN production_wood INT;
ALTER TABLE villages ADD COLUMN production_clay INT;
ALTER TABLE villages ADD COLUMN production_iron INT;
ALTER TABLE villages ADD COLUMN production_crop INT;
