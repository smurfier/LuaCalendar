[ B a c k g r o u n d ]  
 M e t e r = I m a g e  
 H = 1 7 0  
 W = # c W i d t h #  
 S o l i d C o l o r = 0 , 0 , 0 , 1  
 T o o l T i p T e x t = # M o n t h L a b e l #  
 D y n a m i c V a r i a b l e s = 1  
  
 ; D a y   L a b e l   S t y l e s  
 [ L b l T x t S t y ]  
 X = # S p a c i n g X # r  
 Y = 2 7  
 H = 1 6  
 W = 1 6  
 F o n t F a c e = T r e b u c h e t   M S  
 F o n t C o l o r = 2 5 5 , 2 5 5 , 2 5 5  
 S o l i d C o l o r = 2 5 5 , 2 5 5 , 2 5 5 , 2 5  
 F o n t S i z e = 8  
 s t r i n g A l i g n = C e n t e r C e n t e r  
 A n t i A l i a s = 1  
 G r o u p = C o n t r o l s  
  
 [ L b l T x t S t a r t ]  
 X = ( # F i r s t X # - 1 0 )  
  
 [ L b l C u r r S t y ]  
 S o l i d C o l o r = 2 5 5 , 2 5 5 , 2 5 5 , 5 0  
  
 ; M a i n   C a l e n d a r   S t y l e s  
 [ T e x t S t y l e ]  
 X = # S p a c i n g X # r  
 Y = r  
 F o n t C o l o r = 2 5 5 , 2 5 5 , 2 5 5  
 F o n t F a c e = T r e b u c h e t   M S  
 F o n t S i z e = 8  
 s t r i n g A l i g n = R i g h t  
 A n t i A l i a s = 1  
  
 [ F i r s t D a y ]  
 Y = # F i r s t Y #  
 X = # F i r s t X #  
  
 [ N e w W k ]  
 Y = # S p a c i n g Y # r  
 X = 3 8  
  
 [ C u r r e n t D a y ]  
 S t r i n g S t y l e = B o l d  
  
 [ L a s t W e e k ]  
 F o n t C o l o r = 0 , 0 , 0 , 0  
  
 [ P r e v i o u s M o n t h ]  
 F o n t C o l o r = 2 5 5 , 2 5 5 , 2 5 5 , 1 0 8  
  
 [ N e x t M o n t h ]  
 F o n t C o l o r = 2 5 5 , 2 5 5 , 2 5 5 , 1 0 8  
  
 [ H o l i d a y S t y l e ]  
 P r e f i x = "  
 M o u s e O v e r A c t i o n = [ ! S e t O p t i o n   B a c k g r o u n d   T o o l T i p T e x t   " " ] [ ! U p d a t e M e t e r   B a c k g r o u n d ] [ ! R e d r a w ]  
 M o u s e L e a v e A c t i o n = [ ! S e t O p t i o n   B a c k g r o u n d   T o o l T i p T e x t   " # * M o n t h L a b e l * # " ] [ ! U p d a t e M e t e r   B a c k g r o u n d ] [ ! R e d r a w ]  
  
 [ W e e k e n d S t y l e ]  
  
 ; = = = = = = = = = =   M E T E R S   = = = = = = = = = =  
 [ T o p B o r d e r ]  
 M e t e r = I m a g e  
 S o l i d C o l o r = # C l r . B r d #  
 X = 1 0  
 Y = 5  
 W = ( # c W i d t h # - 2 0 )  
 H = 1  
 H i d d e n = # H i d e B o r d e r s T o p #  
  
 [ B o r d e r B o t t o m ]  
 M e t e r = I M A G E  
 S o l i d C o l o r = # C l r . B r d #  
 X = 1 0  
 Y = 1 6 5  
 W = ( # c W i d t h # - 2 0 )  
 H = 1  
 H i d d e n = # H i d e B o r d e r s B o t t o m #  
  
 ; D a t e   I n d i c a t o r  
 [ T o d a y H L ]  
 M e t e r = i m a g e  
 X = ( # F i r s t X # + # W e e k # * F L O O R ( # S p a c i n g X # ) )  
 Y = ( # F i r s t Y # + # S p a c i n g Y # * ( # T h i s W e e k # - 1 ) )  
 H = 1 2  
 W = 2  
 S o l i d C o l o r = # C l r . H r l #  
 H i d d e n = # N o t C u r r e n t M o n t h #  
 D y n a m i c V a r i a b l e s = 1 