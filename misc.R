library(tidyverse)

df <- read_csv('test_dataset.csv') 

df %>% sample_n(10) %>% write_csv('test_dataset_smp.csv')
