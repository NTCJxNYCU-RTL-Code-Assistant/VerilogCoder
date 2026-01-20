module BM_lamda_ref
    //// use Berlekamp Masseys Algorithm to calculate lamda polynomial
    (
    input clk, // input clock planned to be 56 Mhz
    input reset, // active high asynchronous reset

    // input modified syndromes in decimal format 
    input [7:0] Sm1,Sm2,Sm3,Sm4,Sm5,Sm6,Sm7,Sm8,                    
    input [7:0] Sm9,Sm10,Sm11,Sm12,Sm13,Sm14,Sm15,Sm16,    

    //active high flag for one clock to indicate that input Sm is ready
    input Sm_ready,   

    // active high flag for one clock to indicate that erasures values are ready
    input erasure_ready, 
    input [3:0] erasure_cnt,  /// number of erasures per block 0:8 

    input [7:0] pow1,pow2,    /// output of power memories
    input [7:0] dec1,        /// output of decimal memories

    output reg [7:0] add_pow1,add_pow2,     /// address to power memories
    output  [7:0] add_dec1,                              /// address to decimal memories

    // active high flag for one clock to indicate that lamda polynomial is ready
    output reg L_ready,  
    output [7:0] L1,L2,L3,L4,L5,L6,L7,L8   ///  lamda coeff values in decimal format 
    );

    reg [7:0] L [1:9];   /// Lamda polynomial coeff
    reg [7:0] Lt [1:9]; /// temp register for next Lamda polynomial coeff values
    reg [7:0] T [1:10];  /// T polynomial
    reg [7:0] D; /// delta

    reg [4:0]  K;  //  max 16   // operation counter
    reg [3:0]  N;  //  max 8    // operation counter


    reg [3:0]  e_cnt;
    reg [7:0] S [1:16];


    reg [8:0] add_1;   /// address to decimal memory
    reg IS_255_1;
    reg div1;  ///  1  division ,  0 multiplication

    reg [3:0] cnt ;  // max 12

    parameter Step1  = 8'b00000001;
    parameter Step2  = 8'b00000010;
    parameter Step3  = 8'b00000100;
    parameter Step4  = 8'b00001000;
    parameter Step5  = 8'b00010000;
    parameter Step6  = 8'b00100000;
    parameter Step7  = 8'b01000000;
    parameter Step8  = 8'b10000000;

    reg [8:0] const_timing;
    reg [7:0] Step = Step1;

    assign L1=L[2];
    assign L2=L[3];
    assign L3=L[4];
    assign L4=L[5];
    assign L5=L[6];
    assign L6=L[7];
    assign L7=L[8];
    assign L8=L[9];

    //// to handle mutipilcation / division output (address to decimal memory)
    assign add_dec1  =(IS_255_1)?  8'h00 :
                    (&add_1[7:0] && !add_1[8])?     8'h01 : 
                    (div1)? add_1[7:0] - (add_1[8]) +1 :
                    add_1[7:0] +add_1[8] +1 ;

    always@(posedge reset or posedge clk)
    begin
        if (reset)
            begin
                add_1<=0;
                IS_255_1<=0;
                div1<=0;
                add_pow1<=0;add_pow2<=0;
                
                e_cnt<=0;
                
                S[1]<=0;S[2]<=0;S[3]<=0;S[4]<=0;S[5]<=0;
                S[6]<=0;S[7]<=0;S[8]<=0;     
                S[9]<=0;S[10]<=0;S[11]<=0;S[12]<=0;S[13]<=0;
                S[14]<=0;S[15]<=0;S[16]<=0;
                
                L[1]<=0; L[2]<=0; L[3]<=0;L[4]<=0;L[5]<=0;
                L[6]<=0;L[7]<=0;L[8]<=0;L[9]<=0;
                Lt[1]<=0; Lt[2]<=0; Lt[3]<=0;Lt[4]<=0;Lt[5]<=0;
                Lt[6]<=0;Lt[7]<=0;Lt[8]<=0;Lt[9]<=0;
                T[1]<=0; T[2]<=0; T[3]<=0;T[4]<=0;T[5]<=0;
                T[6]<=0;T[7]<=0;T[8]<=0;T[9]<=0;T[10]<=0;
                D<=0;
                K<=0;
                N<=0;
                
                cnt<=0;
                Step<=Step1;
                
                L_ready<=0;
                const_timing<=0;	
            end
        else
            begin
                case (Step)
                /////////////////////////////////////////////////////////////////
                default:begin  /// idle Step    ----- > Step1
                    L[1]<=1; L[2]<=0; L[3]<=0;L[4]<=0;L[5]<=0;
                    L[6]<=0;L[7]<=0;L[8]<=0;L[9]<=0;
                    Lt[1]<=1; Lt[2]<=0; Lt[3]<=0;Lt[4]<=0;Lt[5]<=0;
                    Lt[6]<=0;Lt[7]<=0;Lt[8]<=0;Lt[9]<=0;
                    T[1]<=0; T[2]<=1; T[3]<=0;T[4]<=0;T[5]<=0;
                    T[6]<=0;T[7]<=0;T[8]<=0;T[9]<=0;T[10]<=0;
                    D<=0;
                    K<=0;
                    N<=0;
                    cnt<=0;
                    L_ready<=0;
                    //////// register erasure count///////////////////////////////
                    if(erasure_ready)
                        begin
                            e_cnt<=erasure_cnt;
                        end
                    //// when input modified syndromes are ready//////////
                    if(Sm_ready)
                        begin
                            Step<=Step2;
                            S[1]<=Sm1;S[2]<=Sm2;S[3]<=Sm3;S[4]<=Sm4;S[5]<=Sm5;
                            S[6]<=Sm6;S[7]<=Sm7;S[8]<=Sm8;     
                            S[9]<=Sm9;S[10]<=Sm10;S[11]<=Sm11;S[12]<=Sm12;
                            S[13]<=Sm13;S[14]<=Sm14;S[15]<=Sm15;S[16]<=Sm16;
                        end
                end
                //////////////////////////////////////////////////////////
                Step2:begin
                    K<= K+1;
                    Step<=Step3;
                end
                /////////////////////////////////////////////////////////
                Step3:begin
                    if (N==0)
                        begin
                            D<= S[K+e_cnt];
                            if(S[K+e_cnt]==0)
                                Step<= Step6;
                            else
                                Step <= Step4;
                        end
                    else
                        begin
                        
                            if(cnt == N+4)
                                begin
                                    cnt<=0;
                                    if ( (D^dec1)  == 0)	
                                        Step <= Step6;
                                    else
                                        Step <= Step4;
                                end
                            else
                                cnt<=cnt+1;
                            ///////////////////////////////////////////	
                            if (cnt == 0)
                                begin
                                    D<= S[K+e_cnt];
                                end
                            else if (cnt < 5)
                                begin
                                    add_pow1<= L[cnt+1];
                                    add_pow2<= S[K+e_cnt-cnt];
                                    
                                    div1<=0;
                                    add_1<= pow1 + pow2;
                                    IS_255_1<=(&pow1 || &pow2)? 1:0;
                                end
                            else  /// from 5 to  N+4
                                begin
                                    add_pow1<= L[cnt+1];
                                    add_pow2<= S[K+e_cnt-cnt];
                                    
                                    div1<=0;
                                    add_1<= pow1 + pow2;
                                    IS_255_1<=(&pow1 || &pow2)? 1:0;
                                    
                                    D <= D ^ dec1;
                                end
                        end
                end
                /////////////////////////////////////////////////////////
                Step4:begin
                    ////////////////////////////////////////
                    if(cnt == (11 - e_cnt[3:1]) )
                        begin
                            cnt<=0;
                            Step <= Step5;
                        end
                    else
                        cnt<=cnt+1;
                    ///////////////////////////////////////////	
                    add_pow1<= T[cnt+2];
                    add_pow2 <= D;

                    div1<=0;
                    add_1<= pow1 + pow2;
                    IS_255_1<=(&pow1 || &pow2)? 1:0;
                
                    if (cnt>3) 
                        begin
                            Lt[cnt-2] <= L[cnt-2] ^ dec1;
                        end
                end
                /////////////////////////////////////////////////////////////
                Step5:begin
                    if ({N,1'b0} >= K )     /// 2N >= K
                        begin
                            Step<=Step6;
                            L[1]<=Lt[1]; L[2]<=Lt[2]; L[3]<=Lt[3]; 
                            L[4]<=Lt[4]; L[5]<=Lt[5];
                            L[6]<=Lt[6]; L[7]<=Lt[7];
                            L[8]<=Lt[8]; L[9]<=Lt[9];
                        end
                    else
                        begin
                            ////////////////////////////////////////
                            if(cnt == (12-e_cnt[3:1]) )
                                begin
                                    cnt<=0;
                                    Step <= Step6;
                                    
                                    N <= K - N;
                                    
                                    L[1]<=Lt[1]; L[2]<=Lt[2]; L[3]<=Lt[3];
                                    L[4]<=Lt[4]; L[5]<=Lt[5];
                                    L[6]<=Lt[6]; L[7]<=Lt[7]; 
                                    L[8]<=Lt[8]; L[9]<=Lt[9];
                                end
                            else
                                cnt<=cnt+1;
                            ///////////////////////////////////////////	
                            add_pow1<= L[cnt+1];
                            add_pow2 <= D;

                            div1<=1;
                            add_1<= pow1 - pow2;
                            IS_255_1<=(&pow1 || &pow2)? 1:0;
                        
                            if (cnt>3)  
                                begin
                                    T[cnt-3] <= dec1;
                                end
                            //////////////////////////////////////////////
                        end
                end
                ////////////////////////////////////////////////////////////
                Step6:begin
                    Step<=Step7;
                    T[1]<=0;
                    T[2]<=T[1];
                    T[3]<=T[2];
                    T[4]<=T[3];
                    T[5]<=T[4];
                    T[6]<=T[5];
                    T[7]<=T[6];
                    T[8]<=T[7];
                    T[9]<=T[8];
                    T[10]<=T[9];
                end
                ////////////////////////////////////////////////////////////
                Step7:begin	
                    if(K< 16 - e_cnt)
                        Step<=Step2;
                    else
                        begin
                            Step<=Step8;
                        end
                end
                ////////////////////////////////////////////////////////////
                Step8: begin
                    if(const_timing == 0)
                        begin
                            L_ready<=1;
                            Step<=Step1;
                        end
                end
                ////////////////////////////////////////////////////////////
                endcase
                
                ////////////////  const timing Step machine //////////
                if(Step == Step1)
                    begin
                        //// max possible is estimated to 500 clks
                        const_timing<=500;   
                    end
                else
                    begin
                        const_timing <=const_timing -1;
                    end
                //////////////////////////////////////////
                
            end
    end


endmodule 


module error_correction_ref
    //// evaluate error values, locations and correct it
    (

    input clk, // input clock planned to be 56 Mhz
    input reset, // active high asynchronous reset


    //active high flag for one clock to indicate that Phy and Omega polynomials are ready
    input poly_ready ,
    // decimal value of first coeff of Omega polynomial  
    input  [7:0] O1,    
    /// power values of omega polynomial coeff from 2:16
    input  [7:0] O2,O3,O4,O5,O6,O7,O8,O9,O10,O11,O12,O13,O14,O15,O16,  
    input [7:0] P1,    // decimal value of first coeff of Phy polynomial
    input [7:0] P3,P5,P7,  /// power values of Phy polynomial coeff 

    input roots_ready, // output active high flag to indicate that all roots is ready
    input [3:0] root_count, ///  up to 8
    input [7:0] r1,r2,r3,r4,r5,r6,r7,r8, // roots of lamda polynomial up to 8 roots

    input [7:0] pow1,pow2,pow3,pow4,    /// output of power memories
    input [7:0] dec1,dec2,dec3, dec4,        /// output of decimal memories

    output reg [7:0] add_pow1,add_pow2,add_pow3,add_pow4, /// address to power memories
    output  [7:0] add_dec1,add_dec2,add_dec3,add_dec4,  /// address to decimal memories

    output RE,WE,    //// Write and read enable for input block storage memory
    output reg [7:0] Address,   //// address to input block storage memory
    //// corrected value  =  initial value xor  correction
    output reg [7:0] correction_value,     
    input [7:0] initial_value,  //// input initial value

    output reg DONE

    );


    reg WE_0,RE_0;

    reg [3:0] r_cnt;    ///   root count
    reg [7:0] rd [1:8];   /// roots decimal values
    reg [7:0] rp [1:8];  //// roots power values
    reg [7:0] O [1:16]; //// omega poly
    reg [7:0] P [1:4];  //// phy poly

    reg [7:0] eL [1:8];    /// locations of errors 
    reg [7:0] eV [1:8];   //// power values to evaluate to get correction values


    reg [7:0] V;
    reg [8:0] Vx2;
    reg [9:0] Vx3;
    reg [10:0] Vx6;
    reg [10:0] Vx7;
    reg [10:0] Vx8;
    reg [11:0] Vx9;


    reg [11:0] add1,add2,add3,add4;
    reg [8:0] add_1,add_2,add_3,add_4;


    reg IS_255_1,IS_255_2,IS_255_3,IS_255_4;
    reg IS_255_1_delayed,IS_255_2_delayed,IS_255_3_delayed,IS_255_4_delayed;
    reg div1;

    reg [7:0] OV,PV;   
    ////// OV ==> evalute omega in decimal format
    ////// PV ==> evalute phy in decimal format
    reg [3:0] cnt ;

    reg [3:0] op_cnt;  

    parameter state1  = 7'b0000001;
    parameter state2  = 7'b0000010;
    parameter state3  = 7'b0000100;
    parameter state4  = 7'b0001000;
    parameter state5  = 7'b0010000;
    parameter state6  = 7'b0100000;
    parameter state7  = 7'b1000000;


    reg [6:0] state = state1;

    integer k;
    reg in_range;
    //////////////////////////  assigns /////////////////////////////////
    assign RE = RE_0 ;
    assign WE =(WE_0  &&   ( Address < 188)  && in_range) ? 1:0;



    //// to handle mutipilcation / division output (address to decimal memory)
    assign add_dec1  =(IS_255_1_delayed)?  8'h00 :
                    (&add_1[7:0] && !add_1[8])?     8'h01 : 
                    (div1)? add_1[7:0] - (add_1[8]) +1 : 
                    add_1[7:0] +add_1[8] +1 ;
                    
    assign add_dec2  =(IS_255_2_delayed)?  8'h00 :
                    (&add_2[7:0] )?      8'h01 : 
                    add_2[7:0] +add_2[8] +1 ;

    assign add_dec3  =(IS_255_3_delayed)?  8'h00 :
                    (&add_3[7:0] )?      8'h01 : 
                    add_3[7:0] +add_3[8] +1 ;
                    
    assign add_dec4  =(IS_255_4_delayed)?  8'h00 :
                    (&add_4[7:0] )?      8'h01 : 
                    add_4[7:0] +add_4[8] +1 ;

    always@(posedge clk or posedge reset)
    begin
        if(reset)
            begin
                
                for(k=1;k<=16;k=k+1)
                    begin
                        O[k] <=0;
                    end
                    
                for(k=1;k<=8;k=k+1)
                    begin
                        rd[k]<=0;
                        rp[k]<=0;
                    end
                
                for(k=1;k<=4;k=k+1)
                    begin
                        P[k]<=0;
                    end
                    
                for(k=1;k<=8;k=k+1)
                    begin
                        eL[k]<=0;
                        eV[k]<=0;
                    end	
                        
                WE_0<=0;RE_0<=0;
                    
                r_cnt<=0;	

                V<=0;
                Vx2<=0;
                Vx3<=0;
                Vx6<=0;
                Vx7<=0;
                Vx8<=0;
                Vx9<=0;


                add1<=0;add2<=0;add3<=0;add4<=0;
                add_1<=0;add_2<=0;add_3<=0;add_4<=0;
                IS_255_1<=0;IS_255_2<=0;IS_255_3<=0;IS_255_4<=0;
                IS_255_1_delayed<=0;IS_255_2_delayed<=0;
                IS_255_3_delayed<=0;IS_255_4_delayed<=0;
                div1<=0;
                    
                in_range<=0;
                cnt <=0;
                op_cnt <=0;
                
                add_pow1<=0;add_pow2<=0;add_pow3<=0;add_pow4<=0;
                
                Address<=0;
                correction_value<=0;
                DONE<=0;
                
                OV<=0;PV<=0;
                state<= state1;
            end
        else
            begin
            case(state)
            ///////////////////////////////////////////////////////////
            state1:begin   /// register inputs
                
                for(k=1;k<=8;k=k+1)
                    begin
                        eL[k]<=188;
                        eV[k]<=0;
                    end	
                
                
                if(poly_ready)
                    begin
                        O[1]<=O1;O[2]<=O2;O[3]<=O3;O[4]<=O4;O[5]<=O5;O[6]<=O6;
                        O[7]<=O7;O[8]<=O8;     
                        O[9]<=O9;O[10]<=O10;O[11]<=O11;O[12]<=O12;O[13]<=O13;
                        O[14]<=O14;O[15]<=O15;O[16]<=O16;
                        
                        P[1]<=P1;P[2]<=P3;P[3]<=P5;P[4]<=P7;
                        end
                
                if(roots_ready)
                    begin
                        r_cnt<= root_count;
                        rd[1]<=r1;rd[2]<=r2;rd[3]<=r3;rd[4]<=r4;
                        rd[5]<=r5;rd[6]<=r6;rd[7]<=r7;rd[8]<=r8;
                        state<=state2;
                    end
                    
                    
            end
            ////////////////////////////////////////////////////////
            state2:begin   /// convert roots to power values
                if(cnt == 3 )
                    begin
                        cnt<=1;
                        state<=state3;
                    end
                else
                    cnt<=cnt+1;
                /////////////////////////////////////////////////////	
                case(cnt)
                
                0:begin
                    add_pow1<=rd[1];
                    add_pow2<=rd[2];
                    add_pow3<=rd[3];
                    add_pow4<=rd[4];
                end			
                
                1:begin
                    add_pow1<=rd[5];
                    add_pow2<=rd[6];
                    add_pow3<=rd[7];
                    add_pow4<=rd[8];
                end			
                
                2:begin
                    rp[1]<=pow1;
                    rp[2]<=pow2;
                    rp[3]<=pow3;
                    rp[4]<=pow4;
                end			
                
                default:begin
                    rp[5]<=pow1;
                    rp[6]<=pow2;
                    rp[7]<=pow3;
                    rp[8]<=pow4;
                end			
                
                endcase
            end
            /////////////////////////////////////////////////
            state3:begin   //// allocate eL,eV
                if(cnt == r_cnt)
                    begin
                        cnt<=0;
                        state<=state4;
                        op_cnt <=0;
                    end
                else
                    cnt<=cnt+1;
                ///////////////////////////////////////
                        eL[cnt]<=(rp[cnt]==0)?0:255-rp[cnt];
                        // 0 is a special case
                        // error location = inverse power value of root
                        eV[cnt]<=rp[cnt];				
            end
            ////////////////////////////////////////////////////////
            ////// work with the roots one by one 
            state4:begin
                if(cnt==0)
                    begin
                        op_cnt<=op_cnt+1;
                        cnt<=1;
                        WE_0<=0;
                    end
                else
                    begin
                        
                        if(op_cnt > r_cnt)
                            begin
                                in_range<=0;
                            end
                        else	
                            begin
                                in_range <= 1;
                            end
                        
                        
                        if(op_cnt == 9)
                            begin
                                DONE<=1;
                                cnt<=0;
                                state<=state7;
                            end
                        else
                            begin
                                state<=state5;
                                Address<=203-eL[op_cnt];
                                RE_0<=1;
                                V<= eV[op_cnt];
                                Vx2<= eV[op_cnt]+eV[op_cnt];
                                Vx3<= eV[op_cnt]+eV[op_cnt]+eV[op_cnt];
                                cnt<=0;
                                
                                div1<=0;
                                OV<=O[1];
                                PV<=P[1];
                                correction_value<=0;
                            end
                    end
            end
            ///////////////////////////////////////////////
            state5:begin   /// main operation
                if(cnt == 7)
                    begin
                        cnt<=0;
                        state<=state6;
                    end
                else
                    cnt<=cnt+1;
                ///////////////////////////////////////
                RE_0<=0;
                
                Vx6<=Vx3+Vx3;    /// ready at 1 
                Vx7<=Vx6+V;       /// ready at 2
                Vx8<=Vx6+Vx2;   /// ready at 2
                Vx9<=Vx6+Vx3;   /// ready at 2
                
                IS_255_1_delayed<=IS_255_1;
                IS_255_2_delayed<=IS_255_2;
                IS_255_3_delayed<=IS_255_3;
                IS_255_4_delayed<=IS_255_4;
                
                add_1<= add1[11:8]+add1[7:0];
                add_2<= add2[11:8]+add2[7:0];
                add_3<= add3[11:8]+add3[7:0];
                add_4<= add4[11:8]+add4[7:0];
                ///////////////////////////////////////
                case(cnt)
                
                0:begin
                    add1<= O[2]+V;
                    add2<= O[3]+Vx2;
                    add3<= O[4]+Vx3;
                    add4<= O[5]+Vx3+V;
                    
                    IS_255_1<= (&O[2] || &V)? 1:0;
                    IS_255_2<= (&O[3] || &V)? 1:0;
                    IS_255_3<= (&O[4] || &V)? 1:0;
                    IS_255_4<= (&O[5] || &V)? 1:0;
                end
                
                1:begin
                    add1<= O[6]+Vx2+Vx3;
                    add2<= O[7]+Vx6;
                    add3<= O[8]+Vx6+V;
                    add4<= O[9]+Vx6+Vx2;
                    
                    IS_255_1<= (&O[6] || &V)? 1:0;
                    IS_255_2<= (&O[7] || &V)? 1:0;
                    IS_255_3<= (&O[8] || &V)? 1:0;
                    IS_255_4<= (&O[9] || &V)? 1:0;
                end
                
                2:begin
                    add1<= O[10]+Vx9;
                    add2<= O[11]+Vx9+V;
                    add3<= O[12]+Vx9+Vx2;
                    add4<= O[13]+Vx9+Vx3;
                    
                    IS_255_1<= (&O[10] || &V)? 1:0;
                    IS_255_2<= (&O[11] || &V)? 1:0;
                    IS_255_3<= (&O[12] || &V)? 1:0;
                    IS_255_4<= (&O[13] || &V)? 1:0;
                end
                
                3:begin
                    add1<= O[14]+Vx6+Vx7;
                    add2<= O[15]+Vx6+Vx8;
                    add3<= O[16]+Vx6+Vx9;
                    add4<= 0;
                    
                    IS_255_1<= (&O[14] || &V)? 1:0;
                    IS_255_2<= (&O[15] || &V)? 1:0;
                    IS_255_3<= (&O[16] || &V)? 1:0;
                    IS_255_4<=  1;
                end
                
                default:begin
                    add1<= P[2]+Vx2;
                    add2<= P[3]+Vx3+V;
                    add3<= P[4]+Vx6;
                    add4<= 0;
                
                    IS_255_1<= (&P[2] || &V)? 1:0;
                    IS_255_2<= (&P[3] || &V)? 1:0;
                    IS_255_3<= (&P[4] || &V)? 1:0;
                    IS_255_4<= 1;
                end
                
                endcase
                /////////////////////////////////////////////////
                if(cnt>2 && cnt < 7)   //// from 3 to 6
                    OV<=OV^dec1^dec2^dec3^dec4;
                    
                if(cnt ==7)  // 7
                    PV<=PV^dec1^dec2^dec3^dec4;
                    
            end
            /////////////////////////////////////////////////////
            //// divide OV/PV and write value in output memory	
            state6:begin  	
                if(cnt == 4)
                    begin
                        cnt<=0;
                        WE_0<=1;
                        state<=state4;
                    end	
                else
                    cnt<=cnt+1;
                ///////////////////////////////////////
                div1<=1;
                add_pow1<=OV;
                add_pow2<=PV;
                add_1 <= pow1-pow2;
                IS_255_1_delayed<= (&pow1 || &pow2)? 1:0;
                correction_value<= initial_value ^ dec1;
            end
            ///////////////////////////////////////////////////////
            default:begin    //// state7
                state<= state1;
                DONE<=0;
                cnt<=0;
            end
            /////////////////////////////////////////////////////
            endcase
            end
    end

endmodule 

/// module to calculate syndromes by doing GF_multiply 
// then add outputs of multipliaction
module GF_mult_add_syndromes_ref
    (
    input clk,
    input reset,
    input CE,
    input [7:0] ip1,ip2,   /// power format
    input [2:0] count_in, // input number
    /// active high flag will be active for one clock when S of the RS_block is ready
    output reg S_Ready,  
    output reg [7:0] S   /// decimal format output syndromes value
    );


    reg [8:0] add_inputs;
    reg [7:0] out_GF_mult_0; 


    reg [7:0] address_GF_dec;
    wire[7:0] out_GF_dec; 

    reg [7:0] xor_reg0,xor_reg1,xor_reg2,xor_reg3,xor_reg4,xor_reg5,xor_reg6,xor_reg7; 

    reg [7:0] cnt203_0,cnt203_1,cnt203_2,cnt203_3,cnt203_4,cnt203_5,cnt203_6,cnt203_7;



    reg CE1; 
    //////////////////////GF_matrix_dec Rom //////////////////////////
    GF_matrix_dec rom_instant
    (
    .clk(clk),
    .re(CE || CE1),
    .address_read(address_GF_dec),
    .data_out(out_GF_dec)
    );
    //////////////////////////////////////////////////////////////////



    reg [7:0] ip1_0;
    reg [2:0] count_in0,count_in1,count_in2,count_in3;
    reg F; // to indicate if ip1_0 is FF or not
    ////////////////////////GF_Multiply and accumilation //////////////
    always@(posedge clk or posedge reset)
    begin
        if (reset)
            begin
                add_inputs<=0;
                out_GF_mult_0<=0;
                address_GF_dec<=0;
                
                xor_reg0<=0;xor_reg1<=0;xor_reg2<=0;xor_reg3<=0;
                xor_reg4<=0;xor_reg5<=0;xor_reg6<=0;xor_reg7<=0;
                
                cnt203_0<=204;cnt203_1<=204;cnt203_2<=204;cnt203_3<=204;
                cnt203_4<=204;cnt203_5<=204;cnt203_6<=204;cnt203_7<=204;
                
                S_Ready<=0;
                S<=0;
                F<=1;
                ip1_0<=8'hFF;
                
                count_in0<=0;count_in1<=0;count_in2<=0;count_in3<=0;
                CE1<=1; 
            end
        else
            begin
                if(CE)
                    begin
                        CE1<=0;
                        //======> 1st reg level---------------------------------
                        ip1_0<=ip1;
                        count_in0<=count_in;
                        add_inputs <= ip1+ip2;  //// 9 bits adding
                        
                        //  ======> 2nd reg level -----------------------------------
                        out_GF_mult_0<=add_inputs[7:0]+add_inputs[8];  
                        count_in1<=count_in0;
                        
                        if (&ip1_0)
                        /// to make output take first value in GF_matrix_dec in this case ip1_0 == FF
                            F<=1;  
                        else
                            F<=0;
                        //  ======> 3rd reg level------------------------------------
                        count_in2<=count_in1;
                        address_GF_dec<= (F)? 8'h00:(&out_GF_mult_0)?8'h01:out_GF_mult_0+1;  
                        //  ======> 4th reg level in the Rom latency---------------------
                        count_in3<=count_in2;
                    //////////////////////////////////////////////////////////////////
                        case (count_in3)
                            4: xor_reg4 <= xor_reg4 ^ out_GF_dec;
                            5: xor_reg5 <= xor_reg5 ^ out_GF_dec;
                            6: xor_reg6 <= xor_reg6 ^ out_GF_dec;
                            7: xor_reg7 <= xor_reg7 ^ out_GF_dec;
                            0: xor_reg0 <= xor_reg0 ^ out_GF_dec;
                            1: xor_reg1 <= xor_reg1 ^ out_GF_dec;
                            2: xor_reg2 <= xor_reg2 ^ out_GF_dec;
                            default: xor_reg3 <= xor_reg3 ^ out_GF_dec;
                        endcase	
                    ///////////////////////////////////////////////////////////	
                        
                        //// to make S_ready for only one clock	
                        if (S_Ready)
                            begin
                                S_Ready<=0;
                            end

                        //////////////////////////////////////////////////////////
                        /////////////////////////////////////////////////////////
                        /////////////////////////////////////////////////////////
                        case (count_in)
                        ///////////////////////////////////////////////////////
                        0:
                            begin
                                if (cnt203_0 == 0)
                                    begin
                                        // start of output values , should be taken after this flag is high
                                        S_Ready <= 1; 
                                        cnt203_0<=203;
                                        S<=xor_reg0;
                                        xor_reg0<=0;
                    //// when input frame ends and the first byte of the next frame is 
                    //// entered the output syndromes is available
                                    end
                                else
                                    cnt203_0 <=cnt203_0-1;
                            end
                        ///////////////////////////////////////////////////////////////////////
                        1:
                            begin
                                if (cnt203_1 == 0)
                                    begin
                                        cnt203_1<=203;
                                        S<=xor_reg1;
                                        xor_reg1<=0;
                                        //// when input frame ends and the first byte of the next
                                        ////frame is entered the output syndromes is available
                                    end
                                else
                                    cnt203_1<=cnt203_1-1;
                            end
                        ///////////////////////////////////////////////////////////////
                        2:
                            begin
                                if (cnt203_2 == 0)
                                    begin
                                        cnt203_2<=203;
                                        S<=xor_reg2;
                                        xor_reg2<=0;
                                        //// when input frame ends and the first byte 
                                        //of the next frame is entered the output syndromes is available
                                    end
                                else
                                    cnt203_2<=cnt203_2-1;
                            end
                        ///////////////////////////////////////////////////////////////////////
                        3:
                            begin
                                if (cnt203_3 == 0)
                                    begin
                                        cnt203_3<=203;
                                        S<=xor_reg3;
                                        xor_reg3<=0;
                                        //// when input frame ends and the first byte
                                        ///of the next frame is entered the output syndromes is available
                                    end
                                else
                                    cnt203_3<=cnt203_3-1;
                            end
                        //////////////////////////////////////////////////////////////////////
                        4:
                            begin
                                if (cnt203_4 == 0)
                                    begin
                                        cnt203_4<=203;
                                        S<=xor_reg4;
                                        xor_reg4<=0;
                                        //// when input frame ends and the first byte of
                                        ////the next frame is entered the output syndromes is available
                                    end
                                else
                                    cnt203_4<=cnt203_4-1;
                            end	
                        ////////////////////////////////////////////////////////////////
                        5:
                            begin
                                if (cnt203_5 == 0)
                                    begin
                                        cnt203_5<=203;
                                        S<=xor_reg5;
                                        xor_reg5<=0;
                                        //// when input frame ends and the first byte
                                        ////of the next frame is entered the output syndromes is available
                                    end
                                else
                                    cnt203_5<=cnt203_5-1;
                            end
                        //////////////////////////////////////////////////////////////
                        6:
                            begin
                                if (cnt203_6 == 0)
                                    begin
                                        cnt203_6<=203;
                                        S<=xor_reg6;
                                        xor_reg6<=0;
                                        //// when input frame ends and the first byte of 
                                        ///the next frame is entered the output syndromes is available
                                    end
                                else
                                    cnt203_6 <=cnt203_6-1;
                            end
                        ///////////////////////////////////////////////////
                        default:
                            begin
                                if (cnt203_7 == 0)
                                    begin
                                        cnt203_7<=203;
                                        S<=xor_reg7;
                                        xor_reg7<=0;
                                        //// when input frame ends and the first byte of
                                        ///the next frame is entered the output syndromes is available
                                    end
                                else
                                    cnt203_7 <=cnt203_7-1;
                            end		
                        //////////////////////////////////////
                        endcase	
                    /////////////////////////////////////////////////
                    /////////////////////////////////////////////////
                    ////////////////////////////////////////////////
                    
                    end  // end if CE
                
            end //end  else
    end	// end always	
    //////////////////////////////////////////////////////////////////

endmodule 

module input_syndromes_ref 
    (
    input clk, // clk planned to be 56 mega
    input reset, // asynchorounus active high reset 
    // chip enable active high flag should be active for one clock with every input
    input CE,  
    input [7:0] input_byte, // input byte
    input [7:0] R_Add, // read address to read from inputs pipeling memories
    /// input read enable to the input pipeling memories (1 for mem0, and 0 for mem1 )
    input RE, 

    /// syndromes 16 elements
    /// active high flag will be active for one clock when Syndromes values are ready
    output reg S_Ready,  
    output reg [7:0] s0,s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15,
    output [7:0] Read_byte  /// output byte from input pipelinig memories
    );



    reg WE;
    reg [7:0] input_byte0;
    reg [7:0] W_Add;
    wire [7:0] out_byte_0,out_byte_1;





    assign Read_byte = (RE)? out_byte_0:out_byte_1;
    //////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////
    /////// input pipelining memories
    DP_RAM #(.num_words(205),.address_width(8),.data_width(8)) 
    mem_in_0 

    (
    .clk(clk),
    .we(WE),
    .re(RE),
    .address_read(R_Add),
    .address_write(W_Add),
    .data_in(input_byte0),
    .data_out(out_byte_0)
    );

    DP_RAM  #(.num_words(205),.address_width(8),.data_width(8)) 
    mem_in_1
    (
    .clk(clk),
    .we(!WE),
    .re(!RE),
    .address_read(R_Add),
    .address_write(W_Add),
    .data_in(input_byte0),
    .data_out(out_byte_1)
    );






    //////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////
    ////// input handling

    reg CE0,CE1;
    reg [7:0] Address_GF_ascending;
    wire [7:0] out_GF_ascending;


    always@(posedge clk or posedge reset)
    begin
        if (reset)
            begin
                WE<=1;  /// use mem0 first
                W_Add<=204;
                input_byte0<=0;
                CE0<=0;
                CE1<=0;
                Address_GF_ascending<=0;
            end
        else
            begin
                
                
                //  two delay lines to input CE
                CE0<=CE;
                CE1<=CE0;  // now can read from memory
                
                if(CE)
                    begin
            // one delay line for input as address of memory changes after one clock from CE
                        input_byte0<=input_byte; 
                        Address_GF_ascending<=input_byte;
                        
            // does not need to add one like matlab as memory index from 0 to 255	not from 1:256
                        if (W_Add == 0)
                            begin
                                WE <= ~WE;
                                W_Add <=203;
                            end
                        else
                            W_Add<=W_Add-1;
                    end
            end
    end		








    ///////////// instant of GF_matrix_ascending_binary Rom/////////////
    GF_matrix_ascending_binary rom_instant
    (
    .clk(clk),
    .re(1'b1),
    .address_read(Address_GF_ascending),
    .data_out(out_GF_ascending)
    );


    /////////////////////////////////////////////////////
    ////////////////////////////////////////////////////
    ////// x_power generation

    reg [7:0] x_power_0;

    reg [8:0] x1;
    reg [7:0] x_power_1;

    reg [8:0] x2;
    reg [7:0] x_power_2;

    reg [8:0] x3;
    reg [7:0] x_power_3;

    reg [8:0] x4;
    reg [7:0] x_power_4;

    reg [8:0] x5;
    reg [7:0] x_power_5;

    reg [8:0] x6;
    reg [7:0] x_power_6;

    reg [8:0] x7;
    reg [7:0] x_power_7;

    reg [8:0] x8;
    reg [7:0] x_power_8;


    reg [8:0] x9;
    reg [7:0] x_power_9;

    reg [8:0] x10;
    reg [7:0] x_power_10;

    reg [8:0] x11;
    reg [7:0] x_power_11;

    reg [8:0] x12;
    reg [7:0] x_power_12;

    reg [8:0] x13;
    reg [7:0] x_power_13;

    reg [8:0] x14;
    reg [7:0] x_power_14;

    reg [8:0] x15;
    reg [7:0] x_power_15;
    always@(posedge clk or posedge reset)
    begin
        if (reset)
            begin
                x_power_0<=0;
                                
                x1<=0;
                x_power_1<=0;
                x2<=0;
                x_power_2<=0;
                x3<=0;
                x_power_3<=0;
                x4<=0;
                x_power_4<=0;
                x5<=0;
                x_power_5<=0;
                x6<=0;
                x_power_6<=0;
                x7<=0;
                x_power_7<=0;
                x8<=0;
                x_power_8<=0;
                x9<=0;
                x_power_9<=0;
                x10<=0;
                x_power_10<=0;
                x11<=0;
                x_power_11<=0;
                x12<=0;
                x_power_12<=0;
                x13<=0;
                x_power_13<=0;
                x14<=0;
                x_power_14<=0;
                x15<=0;
                x_power_15<=0;
            end
        else
            begin
                if (CE)
                    begin
                        if (x_power_0 == 0)
                            begin
                                x_power_0<=203;							
                                x1<=151;
                                x2<=99;
                                x3<=47;
                                x4<=250;
                                x5<=198;							
                                x6<=146;							
                                x7<=94;							
                                x8<=42;							
                                x9<=245;						
                                x10<=193;						
                                x11<=141;							
                                x12<=89;							
                                x13<=37;							
                                x14<=240;							
                                x15<=188;
                            end
                        else
                            begin 
                                x_power_0<= x_power_0 - 1;
                                x1<=x_power_1 - 2;
                                x2<=x_power_2 - 3;
                                x3<=x_power_3 - 4;
                                x4<=x_power_4 - 5;
                                x5<=x_power_5 - 6;
                                x6<=x_power_6 - 7;
                                x7<=x_power_7 - 8;
                                x8<=x_power_8 - 9;
                                x9<=x_power_9 - 10;
                                x10<=x_power_10 - 11;
                                x11<=x_power_11 - 12;
                                x12<=x_power_12 - 13;
                                x13<=x_power_13 - 14;
                                x14<=x_power_14 - 15;
                                x15<=x_power_15 - 16;
                            end
                        
                    end
                    
                    x_power_1<= x1[7:0] - x1[8];
                    x_power_2<= x2[7:0] - x2[8];
                    x_power_3<= x3[7:0] - x3[8];
                    x_power_4<= x4[7:0] - x4[8];
                    x_power_5<= x5[7:0] - x5[8];
                    x_power_6<= x6[7:0] - x6[8];
                    x_power_7<= x7[7:0] - x7[8];
                    x_power_8<= x8[7:0] - x8[8];
                    x_power_9<= x9[7:0] - x9[8];
                    x_power_10<= x10[7:0] - x10[8];
                    x_power_11<= x11[7:0] - x11[8];
                    x_power_12<= x12[7:0] - x12[8];
                    x_power_13<= x13[7:0] - x13[8];
                    x_power_14<= x14[7:0] - x14[8];
                    x_power_15<= x15[7:0] - x15[8];
            end
    end
    //// these wires to replace every FF with 00
    wire [7:0] x_power0,x_power1,x_power2,x_power3,x_power4,x_power5,x_power6,x_power7;
    wire [7:0] x_power8,x_power9,x_power10,x_power11,x_power12,x_power13,x_power14,x_power15;

    assign x_power0 = x_power_0;
    assign x_power1 = x_power_1;
    assign x_power2 = (&x_power_2)? 8'h00:x_power_2;
    assign x_power3 = x_power_3;
    assign x_power4 = (&x_power_4)? 8'h00:x_power_4;
    assign x_power5 = (&x_power_5)? 8'h00:x_power_5;
    assign x_power6 = x_power_6;
    assign x_power7 = x_power_7;
    assign x_power8 = (&x_power_8)? 8'h00:x_power_8;
    assign x_power9 = (&x_power_9)? 8'h00:x_power_9;
    assign x_power10 = x_power_10;
    assign x_power11 = (&x_power_11)? 8'h00:x_power_11;
    assign x_power12 = x_power_12;
    assign x_power13 = x_power_13;
    assign x_power14 = (&x_power_14)? 8'h00:x_power_14;
    assign x_power15 = x_power_15;
    //////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////


    //////////////// two instants of syndromes calculation unit ///////////////

    reg CE_GF_mult_add;
    reg [7:0] ip1_0,ip2_0;
    reg [7:0] ip1_1,ip2_1;
    reg [2:0] count_in;
    wire S_Ready_0;
    wire [7:0] s_unit0,s_unit1;

    GF_mult_add_syndromes_ref    unit0
    (
    .clk(clk),
    .reset(reset),
    .CE(CE_GF_mult_add),
    .ip1(ip1_0),
    .ip2(ip2_0),  
    .count_in(count_in), 
    /// active high flag will be active for one clock when S of the RS_block is ready 
    .S_Ready(S_Ready_0),  
    /// decimal format output syndromes value
    .S(s_unit0)  
    );



    GF_mult_add_syndromes_ref    unit1
    (
    .clk(clk),
    .reset(reset),
    .CE(CE_GF_mult_add),
    .ip1(ip1_1),
    .ip2(ip2_1),
    .count_in(count_in),  
    .S_Ready(), 
    /// decimal format output syndromes value
    .S(s_unit1)  
    );


    /////////////////// control inputs to two syndromes units//////////

    always@(posedge clk or posedge reset)
    begin
        if (reset)
            begin
                CE_GF_mult_add<=0;
                count_in<=7;
                ip1_0<=0;ip2_0<=0;
                ip1_1<=0;ip2_1<=0;
            end
        else
            begin
                if(CE1)
                    begin
                        CE_GF_mult_add<=1;
                        count_in<=0;
                        ip1_0<=out_GF_ascending; 
                        ip1_1<=out_GF_ascending; 
                    end	
                if (&count_in  &&  !CE1)
                        begin
                        count_in <= 3'd7;
                        CE_GF_mult_add<=0;
                    end 
                else		
                    count_in <= count_in+1;
                    
                case(count_in)
                0:
                    begin	
                        ip2_0<=x_power2;
                        ip2_1<=x_power3;
                    end
                
                1:
                    begin	
                        ip2_0<=x_power4;
                        ip2_1<=x_power5;
                    end
                
                2:
                    begin	
                        ip2_0<=x_power6;
                        ip2_1<=x_power7;
                    end
                
                3:
                    begin	
                        ip2_0<=x_power8;
                        ip2_1<=x_power9;
                    end
                
                4:
                    begin	
                        ip2_0<=x_power10;
                        ip2_1<=x_power11;
                    end
                
                5:
                    begin	
                        ip2_0<=x_power12;
                        ip2_1<=x_power13;
                    end
                
                6:
                    begin	
                        ip2_0<=x_power14;
                        ip2_1<=x_power15;
                    end
                default:
                    begin	
                        ip2_0<=x_power0;
                        ip2_1<=x_power1;
                    end	
                endcase	
            end
    end


    /////////////////// control output 16 syndromes values/////////////

    reg [2:0] cnt8;

    always@(posedge clk or posedge reset)
    begin
        if (reset)
            begin
                cnt8<=7;
                S_Ready<=0;
                s0<=0;s1<=0;s2<=0;s3<=0;s4<=0;s5<=0;s6<=0;s7<=0;
                s8<=0;s9<=0;s10<=0;s11<=0;s12<=0;s13<=0;s14<=0;s15<=0;
            end
        else
            begin
                if(S_Ready_0)
                    begin
                        cnt8<=0;
                    end
                
                if (&cnt8  &&  !S_Ready_0)
                        begin
                        cnt8 <= 3'd7;
                    end
                else
                    cnt8<=cnt8+1;
                    
                    
                case (cnt8)
                    0:begin s2<=s_unit0; s3<=s_unit1; end
                    1:begin s4<=s_unit0; s5<=s_unit1; end
                    2:begin s6<=s_unit0; s7<=s_unit1; end
                    3:begin s8<=s_unit0; s9<=s_unit1; end
                    4:begin s10<=s_unit0; s11<=s_unit1; end
                    5:begin s12<=s_unit0; s13<=s_unit1; end
                    6:begin s14<=s_unit0; s15<=s_unit1;   S_Ready<=1; end
                    default:begin  s0<=s_unit0; s1<=s_unit1; end
                endcase			
                    
                if (S_Ready)
                    S_Ready<=0;
            end
    end

endmodule

module lamda_roots_ref
    (
    // active high flag for one clock edge to indicate that lamda polynomial coeff is ready
    input CE,  
    input clk, // input clock planned to be 56 Mhz
    input reset, // active high asynchronous reset
    input [7:0] Lc0,Lc1,Lc2,Lc3,Lc4,Lc5,Lc6,Lc7,Lc8, /// input coeff of lamda polynomial

    output reg [7:0] add_GF_ascending,   // output address to GF_ascending_rom
    output reg[7:0] add_GF_dec0,add_GF_dec1,add_GF_dec2, // output address to GF_dec_rom

    input [7:0] power,  // input power value from GF_ascending_rom
    input [7:0] decimal0,decimal1,decimal2, // input decimal value of GF_dec_rom

    // output active high flag to indicate that all roots is ready (for one clock)
    output reg CEO,
    output reg [3:0] root_cnt, ///  up to 8
    // output roots of lamda polynomial up to 8 roots
    output reg [7:0] r1,r2,r3,r4,r5,r6,r7,r8 
    );


    reg one,two; //states
    /// decimal value & power value of possible values of roots 0---255
    reg [7:0] V,Vp;  
    reg [3:0] cnt9;
    reg [1:0] cnt3;

    reg [11:0] add0,add1,add2;
    reg [8:0] Vx2;
    reg [9:0] Vx3;
    reg [10:0] Vx6;
    reg [7:0] X0,X1,X2,X3;   /// xor values
    reg [7:0] GF1,GF2,GF3,GF4; /// decimal GF values
    reg [7:0] GF5,GF6,GF7,GF8; /// decimal GF values
    reg [8:0] add_GF_dec0_reg,add_GF_dec1_reg,add_GF_dec2_reg;
    reg [7:0] add_GF_dec0_reg0,add_GF_dec1_reg0,add_GF_dec2_reg0;
    reg F0,F1,F2;   /// IS 255
    reg FF0,FF1,FF2; /// IS 255 delayed one clock
    reg FFF0,FFF1,FFF2; /// IS 255  delayed two clocks
    reg [7:0] L0,L1,L2,L3,L4,L5,L6,L7,L8; /// Lamda coeff
    reg yes,E;
    reg chk_flag; 
    reg [1:0] chk_cnt;
    //////////////////////////////////////////////////////////////////
    //////////////////////////////////////////////////////////////////
    /////////////////// values generator (0--255  every three clocks)
    always@(posedge clk or posedge reset)
    begin
        if (reset)
            begin
                cnt3<=2;
                V<=8'd255;
            end
        else
            begin
                if(two)
                    begin
                        if (cnt3 ==2)
                            begin
                                cnt3<=0;
                                V<=V+1;
                            end
                        else	
                            cnt3<=cnt3+1;
                    end
                else
                    begin
                        cnt3<=2;
                        V<=8'd255;
                    end
            end
    end



    /////////////////////////////////////////////////////////////////
    /////////////////////////////////////////////////////////////////
    /////////////////// main process
    always@(posedge clk or posedge reset)
    begin
        if (reset)
            begin
                one<=0;
                two<=0;
                cnt9<=0;
                L0<=0;L1<=0;L2<=0;L3<=0;L4<=0;
                L5<=0;L6<=0;L7<=0;L8<=0;
                add_GF_dec0_reg<=0;add_GF_dec1_reg<=0;add_GF_dec2_reg<=0;
                add_GF_dec0_reg0<=0;add_GF_dec1_reg0<=0;add_GF_dec2_reg0<=0;
                F0<=0;F1<=0;F2<=0;
                FF0<=0;FF1<=0;FF2<=0;
                FFF0<=0;FFF1<=0;FFF2<=0;
                add0<=0;add1<=0;add2<=0;
                Vx2<=0;Vx3<=0;Vx6<=0;Vp<=0;
                X0<=0;X1<=0;X2<=0;X3<=0;
                GF1<=0;GF2<=0;GF3<=0;GF4<=0;
                GF5<=0;GF6<=0;GF7<=0;GF8<=0;
                yes<=0;
                E<=0;
                chk_flag<=0; chk_cnt<=0;
                ////////////////outputs///////////////////////
                root_cnt<=0;
                CEO<=0;
                r1<=0;r2<=0;r3<=0;r4<=0;
                r5<=0;r6<=0;r7<=0;r8<=0;
                add_GF_dec0<=0;add_GF_dec1<=0;add_GF_dec2<=0;
                add_GF_ascending<=0;
            end
        else
            begin
                if(CE)
                    begin
                        one<=1;
                        L0<=Lc0; // no need to convert it to power form
                        add_GF_ascending<=Lc1;
                        L2<=Lc2;L3<=Lc3;L4<=Lc4;
                        L5<=Lc5;L6<=Lc6;L7<=Lc7;L8<=Lc8;
                        cnt9<=7;
                    end
                ////// state one////////////////////////////////////////////////	
                if(one)
                    begin
                        cnt9<=cnt9-1;
                        /////////////////////////////////
                        case(cnt9)
                        7: begin add_GF_ascending<=L2; end
                        6: begin add_GF_ascending<=L3; L1<=power; end
                        5: begin add_GF_ascending<=L4; L2<=power; end
                        4: begin add_GF_ascending<=L5; L3<=power; end
                        3: begin add_GF_ascending<=L6; L4<=power; end
                        2: begin add_GF_ascending<=L7; L5<=power; end
                        1: begin add_GF_ascending<=L8; L6<=power; end
                        0: begin  L7<=power;  end
                        15:begin 
                                L8<=power;  one<=0; two<=1; root_cnt<=0;
                                /// to avoid false roots from xor operations
                                X0<=8'h55;X1<=8'hAA;X2<=8'hF1;X3<=8'h55;
                                GF1<=0;GF2<=0;GF3<=0;GF4<=0;
                                GF5<=0;GF6<=0;GF7<=0;GF8<=0;
                                r1<=0;r2<=0;r3<=0;r4<=0;
                                r5<=0;r6<=0;r7<=0;r8<=0;
                                chk_flag<=0; chk_cnt<=0;
                            end
                        default: begin   add_GF_ascending<=L2;       end   /// just for default case
                        endcase
                        //////////////////////////////////
                    end	
                ////// state two////////////////////////////////////
                if(two)
                    begin
                        ///////////////Delay level one ////////////////////
                        if(cnt3 == 0)
                            begin
                                add_GF_ascending<=V;
                            end
                        //////////////////////////////////////////////////////
                        ///////////////////////////Delay level  two//////////
                        Vp <=power;
                        ////////////////////////////////////////////////////////
                        ///////////////////////////Delay level  three//////////
                        case (cnt3)  
                        0:
                            begin
                                add0<=L1+Vp;
                                add1<=L2+Vp+Vp;
                                add2<=0;
                                F0<= (&L1 || &Vp);
                                F1<=(&L2 || &Vp);
                                F2<=0;
                            end
                        1:
                            begin
                                add0<=L3+Vx3;
                                add1<=L4+Vx3+Vp;
                                add2<=L5+Vx3+Vx2;
                                F0<= (&L3 || &Vp);
                                F1<=(&L4 || &Vp);
                                F2<=(&L5 || &Vp);
                            end
                        2:
                            begin
                                add0<=L6+Vx6;
                                add1<=L7+Vx6+Vp;
                                add2<=L8+Vx6+Vx2;
                                F0<= (&L6 || &Vp);
                                F1<=(&L7|| &Vp);
                                F2<=(&L8 || &Vp);
                            end
                        default:
                            begin /// using first case values for default
                                add0<=L1+Vp;
                                add1<=L2+Vp+Vp;
                                add2<=0;
                                F0<= (&L1 || &Vp);
                                F1<=(&L2 || &Vp);
                                F2<=0;
                            end	 
                        endcase
                        //// Vp constant for 3 clocks so these operations can  
                        /////be done without using operation switcher cnt3
                        Vx2<=Vp+Vp;
                        Vx3<=Vp+Vp+Vp;
                        Vx6<=Vx3+Vx3;
                        
                        ////////////////////////////////////////////////////
                        ///////////////////////////Delay level  four/////////
                        /// 8 + 4 ===> need 9 bits
                        add_GF_dec0_reg<=add0[11:8] + add0[7:0];   
                        add_GF_dec1_reg<=add1[11:8] + add1[7:0];
                        add_GF_dec2_reg<=add2[11:8] + add2[7:0];
                        
                        FF0<=F0; FF1<=F1; FF2<=F2;
                        ///////////////////////////////////////////////////
                        ///////////////////////////Delay level  five///////
                        ///   9 bits  =====> 8 bits
                        add_GF_dec0_reg0<=add_GF_dec0_reg[8] + add_GF_dec0_reg[7:0];  
                        add_GF_dec1_reg0<=add_GF_dec1_reg[8] + add_GF_dec1_reg[7:0];
                        add_GF_dec2_reg0<=add_GF_dec2_reg[8] + add_GF_dec2_reg[7:0];
                        
                        FFF0<=FF0; FFF1<=FF1; FFF2<=FF2;
                        //////////////////////////////////////////////////////////
                        ///////////////////////////Delay level  six/////////////
                        add_GF_dec0 <= (FFF0)?  8'h00 : (&add_GF_dec0_reg0)? 8'h01:add_GF_dec0_reg0+1;
                        add_GF_dec1 <= (FFF1)?  8'h00 : (&add_GF_dec1_reg0)? 8'h01:add_GF_dec1_reg0+1;
                        add_GF_dec2 <= (FFF2)?  8'h00 : (&add_GF_dec2_reg0)? 8'h01:add_GF_dec2_reg0+1;
                        ////////////////////////////////////////////////////////
                        ///////////////////////////Delay level  seven///////////
                        X0<=L0;
                        GF1<=decimal0;
                        GF2<=decimal1;
                        ///////////////////////////////////////////////////////
                        ///////////////////////////Delay level  eight/////////
                        X1<=X0 ^ GF1^GF2;
                        GF3<=decimal0;
                        GF4<=decimal1;
                        GF5<=decimal2;
                        //////////////////////////////////////////////////////
                        ///////////////////////////Delay level  nine/////////
                        X2<=X1 ^ GF3^GF4^GF5;
                        GF6<=decimal0;
                        GF7<=decimal1;
                        GF8<=decimal2;
                        /////////////////////////////////////////////////////
                        ///////////////////////////Delay level  ten/////////
                        X3<=X2 ^ GF6^GF7^GF8;
                        ////////////////////////////////////////////////////
                        ///////////////////////////Delay level  eleven//////
                        if (X3==0  && chk_flag && cnt3==0)
                            begin
                                root_cnt<=root_cnt+1;
                                yes<=1;
                            end
                        /////////////////////////////////////////////////////
                        ///////////////////////////Delay level  twelve//////
                        if(yes)
                            begin
                                yes<=0;
                                case(root_cnt)
                                1: begin r1<=V-8'd4; end
                                2: begin r2<=V-8'd4; end
                                3: begin r3<=V-8'd4; end
                                4: begin r4<=V-8'd4; end
                                5: begin r5<=V-8'd4; end
                                6: begin r6<=V-8'd4; end
                                7: begin r7<=V-8'd4; end
                                default: begin r8<=V-8'd4; end
                                endcase
                            end
                        //////////////////////////////////////////////////
                        ///////////////////////////Delay level  thirteen//
                        if(&(V-8'd4)  &&  E  && cnt3 == 1)   
                        // when value == 255+delay , we now scanned all possible values of roots 
                            begin
                                two<=0;
                                CEO<=1;
                                E<=0;
                            end
                            
                        if(&V && cnt3==0)  
                        // when value == 255 and cnt3 ==0 so 255 value entered state two
                            E<=1;
                        ////////////////////////////////////////////////////
                        /////////////////////chk_flag generation part//////
                        /////to control the check of X3 (xor out value) only with right places .
                        if(cnt3 == 0)
                            begin
                                if(&chk_cnt)
                                    begin
                                        chk_cnt<= 2'd3;
                                        chk_flag<=1;
                                    end
                                else
                                    chk_cnt<=chk_cnt+1;
                            end
                    end
                ///////////////////////////////////////////////
                if (CEO)
                    CEO<=0; /// to make it active for one clock
            end
    end		



endmodule 

module Omega_Phy_ref
    ///// calculates Omega and Phy polynomials 
    ///    Omega = (Syndromes_16 * Lamda_8)  mod16
    ///    Phy = dirvetive (Lamda_8)      
    (

    input clk, // input clock planned to be 56 Mhz
    input reset, // active high asynchronous reset

    //   active high flag for one clock to indicate that input Sm is ready
    input Sm_ready,  
    // input modified syndromes in decimal format 
    input [7:0] Sm1,Sm2,Sm3,Sm4,Sm5,Sm6,Sm7,Sm8,                
    input [7:0] Sm9,Sm10,Sm11,Sm12,Sm13,Sm14,Sm15,Sm16,    

    // active high flag for one clock to indicate that lamda polynomial is ready
    input L_ready, 
    ///  lamda coeff values in decimal format 
    input [7:0] L1,L2,L3,L4,L5,L6,L7,L8,  

    input [7:0] pow1,pow2,pow3,  /// output of power memories
    input [7:0] dec1,        	/// output of decimal memories

    output reg [7:0] add_pow1,add_pow2,add_pow3, /// address to power memories
    output  [7:0] add_dec1,              		 /// address to decimal memories

    // active high flag for one clock to indicate that Phy and Omega polynomials are ready
    output reg poly_ready ,  
    // decimal value of first coeff of Omega polynomial
    output  [7:0] O1,    
    /// power values of omega polynomial coeff from 2:16
    output  [7:0] O2,O3,O4,O5,O6,O7,O8,O9,O10,O11,O12,O13,O14,O15,O16,  

    output  reg [7:0] P1,    // decimal value of first coeff of Phy polynomial
    output  reg [7:0] P3,P5,P7  /// power values of phy polynomial 


    );



    parameter state1    =  19'b0000000000000000001;
    parameter state2    =  19'b0000000000000000010;
    parameter state10  =  19'b0000000000000000100;
    parameter state11  =  19'b0000000000000001000;
    parameter state12  =  19'b0000000000000010000;
    parameter state13  =  19'b0000000000000100000;
    parameter state14  =  19'b0000000000001000000;
    parameter state15  =  19'b0000000000010000000;
    parameter state16  =  19'b0000000000100000000;
    parameter state17  =  19'b0000000001000000000;
    parameter state18  =  19'b0000000010000000000;
    parameter state19  =  19'b0000000100000000000;
    parameter state20  =  19'b0000001000000000000;
    parameter state21  =  19'b0000010000000000000;
    parameter state22  =  19'b0000100000000000000;
    parameter state23  =  19'b0001000000000000000;
    parameter state24  =  19'b0010000000000000000;
    parameter state25  =  19'b0100000000000000000;
    parameter state26  =  19'b1000000000000000000;

    reg [18:0] state = state1;


    reg [7:0] Sp [1:15]; // syndromes power values
    reg [7:0] L   [1:8]; // lamda decimal values
    reg [7:0] Lp [1:8];  // lamda power values

    reg [7:0] O [1:16]; // omega values

    assign O1=O[1];
    assign O2=O[2];
    assign O3=O[3];
    assign O4=O[4];
    assign O5=O[5];
    assign O6=O[6];
    assign O7=O[7];
    assign O8=O[8];
    assign O9=O[9];
    assign O10=O[10];
    assign O11=O[11];
    assign O12=O[12];
    assign O13=O[13];
    assign O14=O[14];
    assign O15=O[15];
    assign O16=O[16];


    reg [3:0]  cnt;
    reg [3:0]  cnt1;
    reg [3:0]  cnt2;


    reg [8:0] add_1;
    reg F1;  // is 255 flag

    assign add_dec1  =(F1)?  8'h00 :(&add_1[7:0])?     8'h01 : add_1[7:0]+add_1[8]+1;

    integer k;

    always@ (posedge clk or posedge reset)
    begin
        if (reset)
            begin
                poly_ready<=0;
                P1<= 0;P3<= 0;P5<= 0;P7<= 0;
                add_pow1<=0;add_pow2<=0;add_pow3<=0;
                
                add_1<=0;
                F1<=0;
                
                for(k=1;k<=15;k=k+1)
                    begin
                        Sp[k] <=0;
                        O[k] <=0;
                    end
                    
                for(k=1;k<=8;k=k+1)
                    begin
                        L[k]<=0;
                        Lp[k]<=0;
                    end

                O[16] <=0;
                
                cnt<=0;
                cnt1<=0;
                cnt2<=0;
                state<=state1;
            end
        else
            begin
                case (state)
                ////////////////////////////////////////////
                state1:begin       ///// register inputs
                    
                    if(Sm_ready)
                        begin
                            O[1]<=Sm1;
                            O[2]<=Sm2;O[3]<=Sm3;O[4]<=Sm4;O[5]<=Sm5;
                            O[6]<=Sm6;O[7]<=Sm7;O[8]<=Sm8;O[9]<=Sm9;     
                            O[10]<=Sm10;O[11]<=Sm11;O[12]<=Sm12;
                            O[13]<=Sm13;O[14]<=Sm14;O[15]<=Sm15;O[16]<=Sm16;
                        end
                    
                    if(L_ready)
                        begin
                            L[1]<=L1;L[2]<=L2;L[3]<=L3;L[4]<=L4;L[5]<=L5;
                            L[6]<=L6;L[7]<=L7;L[8]<=L8;
                            P1<= L1;P3<= 255;P5<= 255;P7<= 255;
                            state<=state2;	
                            end
                    cnt<=0;	
                end
                /////////////////////////////////////////////////////////////
                state2:begin  //// get power values of  syndromes and lamda coeff
                    
                    if (cnt == 9)
                        begin
                            state<=state10;   
                            cnt<=0;
                        end
                    else
                        cnt<=cnt+1;
                    ///////////////////////////////////////
                    case(cnt)
                    
                    0:begin
                        add_pow1<= O[1];
                        add_pow2<= O[2];
                        add_pow3<= O[3];
                    end
                    
                    1:begin
                        add_pow1<= O[4];
                        add_pow2<= O[5];
                        add_pow3<= O[6];
                    end
                    
                    2:begin
                        add_pow1<= O[7];
                        add_pow2<= O[8];
                        add_pow3<= O[9];
                        
                        
                        Sp[1] <= pow1;
                        Sp[2] <= pow2;
                        Sp[3] <= pow3;
                    end
                    
                    3:begin
                        add_pow1<= O[10];
                        add_pow2<= O[11];
                        add_pow3<= O[12];
                        
                        Sp[4] <= pow1;
                        Sp[5] <= pow2;
                        Sp[6] <= pow3;
                    end
                    
                    4:begin
                        add_pow1<= O[13];
                        add_pow2<= O[14];
                        add_pow3<= O[15];
                        
                        Sp[7] <= pow1;
                        Sp[8] <= pow2;
                        Sp[9] <= pow3;
                    end
                    
                    5:begin
                        add_pow1<= L[1];
                        add_pow2<= L[2];
                        add_pow3<= L[3];
                        
                        Sp[10] <= pow1;
                        Sp[11] <= pow2;
                        Sp[12] <= pow3;
                    end
                    
                    6:begin
                        add_pow1<= L[4];
                        add_pow2<= L[5];
                        add_pow3<= L[6];
                        
                        Sp[13] <= pow1;
                        Sp[14] <= pow2;
                        Sp[15] <= pow3;
                    end
                    
                    7:begin
                        add_pow1<= L[7];
                        add_pow2<= L[8];
                        
                        Lp[1] <= pow1;
                        Lp[2] <= pow2;
                        Lp[3] <= pow3;
                        
                        P3<=pow3;
                    end
                    
                    8:begin
                        Lp[4] <= pow1;
                        Lp[5] <= pow2;
                        Lp[6] <= pow3;
                        
                        P5<=pow2;
                    end
                    
                    default:begin
                        Lp[7] <= pow1;
                        Lp[8] <= pow2;
                        
                        P7<=pow1;
                    end
                    
                    endcase	
                end
                /////////////////////////////////////////////////////
                /// just a name for the next state but it is state number three in sequence
                state10:begin   //// calculate O2
                    if(cnt == 2)
                        begin
                            state<=state11;
                            cnt<=0;
                            cnt1<=1;
                            cnt2<=2;
                        end
                    else
                        cnt<=cnt+1;
                    
                    add_1<= Sp[1]+Lp[1];
                    F1<= (&Sp[1] || &Lp[1])? 1:0;
                    
                    if(cnt == 2)
                        O[2] <= O[2] ^ dec1;
                        
                end
                /////////////////////////////////////////////////
                state11:begin     /// O3 calculation
                    if(cnt == 2)
                        begin
                            cnt<=0;
                            O[3]<=O[3]^dec1;
                        end
                    else
                        cnt<=cnt+1;
                    /////////////////////////////////////////
                    if (cnt == 2)
                        begin
                            if (cnt2 == 1)
                                begin
                                    cnt2<=3;
                                    cnt1<=1;
                                    state<=state12;
                                end
                            else
                                begin
                                    cnt2<=cnt2-1;
                                    cnt1<=cnt1+1;
                                end
                        end
                    ////////////////////////////////////////
                    add_1 <= Lp[cnt1] + Sp[cnt2];
                    F1<= (&Lp[cnt1]  ||  &Sp[cnt2])? 1:0;
                end
                /////////////////////////////////////////////////
                state12:begin     /// O4 calculation
                    if(cnt == 2)
                        begin
                            cnt<=0;
                            O[4]<=O[4]^dec1;
                        end
                    else
                        cnt<=cnt+1;
                    /////////////////////////////////////////
                    if (cnt == 2)
                        begin
                            if (cnt2 == 1)
                                begin
                                    cnt2<=4;
                                    cnt1<=1;
                                    state<=state13;
                                end
                            else
                                begin
                                    cnt2<=cnt2-1;
                                    cnt1<=cnt1+1;
                                end
                        end
                    ////////////////////////////////////////
                    add_1 <= Lp[cnt1] + Sp[cnt2];
                    F1<= (&Lp[cnt1]  ||  &Sp[cnt2])? 1:0;
                end
                ///////////////////////////////////////////////////
                state13:begin     /// O5 calculation
                    if(cnt == 2)
                        begin
                            cnt<=0;
                            O[5]<=O[5]^dec1;
                        end
                    else
                        cnt<=cnt+1;
                    /////////////////////////////////////////
                    if (cnt == 2)
                        begin
                            if (cnt2 == 1)
                                begin
                                    cnt2<=5;
                                    cnt1<=1;
                                    state<=state14;
                                end
                            else
                                begin
                                    cnt2<=cnt2-1;
                                    cnt1<=cnt1+1;
                                end
                        end
                    ////////////////////////////////////////
                    add_1 <= Lp[cnt1] + Sp[cnt2];
                    F1<= (&Lp[cnt1]  ||  &Sp[cnt2])? 1:0;
                end
                ////////////////////////////////////////////////////
                state14:begin     /// O6 calculation
                    if(cnt == 2)
                        begin
                            cnt<=0;
                            O[6]<=O[6]^dec1;
                        end
                    else
                        cnt<=cnt+1;
                    /////////////////////////////////////////
                    if (cnt == 2)
                        begin
                            if (cnt2 == 1)
                                begin
                                    cnt2<=6;
                                    cnt1<=1;
                                    state<=state15;
                                end
                            else
                                begin
                                    cnt2<=cnt2-1;
                                    cnt1<=cnt1+1;
                                end
                        end
                    ////////////////////////////////////////
                    add_1 <= Lp[cnt1] + Sp[cnt2];
                    F1<= (&Lp[cnt1]  ||  &Sp[cnt2])? 1:0;
                end
                ///////////////////////////////////////////////////
                state15:begin     /// O7 calculation
                    if(cnt == 2)
                        begin
                            cnt<=0;
                            O[7]<=O[7]^dec1;
                        end
                    else
                        cnt<=cnt+1;
                    /////////////////////////////////////////
                    if (cnt == 2)
                        begin
                            if (cnt2 == 1)
                                begin
                                    cnt2<=7;
                                    cnt1<=1;
                                    state<=state16;
                                end
                            else
                                begin
                                    cnt2<=cnt2-1;
                                    cnt1<=cnt1+1;
                                end
                        end
                    ////////////////////////////////////////
                    add_1 <= Lp[cnt1] + Sp[cnt2];
                    F1<= (&Lp[cnt1]  ||  &Sp[cnt2])? 1:0;
                end
                ////////////////////////////////////////////////
                state16:begin     /// O8 calculation
                    if(cnt == 2)
                        begin
                            cnt<=0;
                            O[8]<=O[8]^dec1;
                        end
                    else
                        cnt<=cnt+1;
                    /////////////////////////////////////////
                    if (cnt == 2)
                        begin
                            if (cnt2 == 1)
                                begin
                                    cnt2<=8;
                                    cnt1<=1;
                                    state<=state17;
                                end
                            else
                                begin
                                    cnt2<=cnt2-1;
                                    cnt1<=cnt1+1;
                                end
                        end
                    ////////////////////////////////////////
                    add_1 <= Lp[cnt1] + Sp[cnt2];
                    F1<= (&Lp[cnt1]  ||  &Sp[cnt2])? 1:0;
                end
                //////////////////////////////////////////////
                state17:begin     /// O9 calculation
                    if(cnt == 2)
                        begin
                            cnt<=0;
                            O[9]<=O[9]^dec1;
                        end
                    else
                        cnt<=cnt+1;
                    /////////////////////////////////////////
                    if (cnt == 2)
                        begin
                            if (cnt2 == 1)
                                begin
                                    cnt2<=9;
                                    cnt1<=1;
                                    state<=state18;
                                end
                            else
                                begin
                                    cnt2<=cnt2-1;
                                    cnt1<=cnt1+1;
                                end
                        end
                    ////////////////////////////////////////
                    add_1 <= Lp[cnt1] + Sp[cnt2];
                    F1<= (&Lp[cnt1]  ||  &Sp[cnt2])? 1:0;
                end
                //////////////////////////////////////////////////
                state18:begin     /// O10 calculation
                    if(cnt == 2)
                        begin
                            cnt<=0;
                            O[10]<=O[10]^dec1;
                        end
                    else
                        cnt<=cnt+1;
                    /////////////////////////////////////////
                    if (cnt == 2)
                        begin
                            if (cnt2 == 2)
                                begin
                                    cnt2<=10;
                                    cnt1<=1;
                                    state<=state19;
                                end
                            else
                                begin
                                    cnt2<=cnt2-1;
                                    cnt1<=cnt1+1;
                                end
                        end
                    ////////////////////////////////////////
                    add_1 <= Lp[cnt1] + Sp[cnt2];
                    F1<= (&Lp[cnt1]  ||  &Sp[cnt2])? 1:0;
                end
                ///////////////////////////////////////////////////
                state19:begin     /// O11 calculation
                    if(cnt == 2)
                        begin
                            cnt<=0;
                            O[11]<=O[11]^dec1;
                        end
                    else
                        cnt<=cnt+1;
                    /////////////////////////////////////////
                    if (cnt == 2)
                        begin
                            if (cnt2 == 3)
                                begin
                                    cnt2<=11;
                                    cnt1<=1;
                                    state<=state20;
                                end
                            else
                                begin
                                    cnt2<=cnt2-1;
                                    cnt1<=cnt1+1;
                                end
                        end
                    ////////////////////////////////////////
                    add_1 <= Lp[cnt1] + Sp[cnt2];
                    F1<= (&Lp[cnt1]  ||  &Sp[cnt2])? 1:0;
                end
                /////////////////////////////////////////////////
                state20:begin     /// O12 calculation
                    if(cnt == 2)
                        begin
                            cnt<=0;
                            O[12]<=O[12]^dec1;
                        end
                    else
                        cnt<=cnt+1;
                    /////////////////////////////////////////
                    if (cnt == 2)
                        begin
                            if (cnt2 == 4)
                                begin
                                    cnt2<=12;
                                    cnt1<=1;
                                    state<=state21;
                                end
                            else
                                begin
                                    cnt2<=cnt2-1;
                                    cnt1<=cnt1+1;
                                end
                        end
                    ////////////////////////////////////////
                    add_1 <= Lp[cnt1] + Sp[cnt2];
                    F1<= (&Lp[cnt1]  ||  &Sp[cnt2])? 1:0;
                end
                /////////////////////////////////////////
                state21:begin     /// O13 calculation
                    if(cnt == 2)
                        begin
                            cnt<=0;
                            O[13]<=O[13]^dec1;
                        end
                    else
                        cnt<=cnt+1;
                    /////////////////////////////////////////
                    if (cnt == 2)
                        begin
                            if (cnt2 == 5)
                                begin
                                    cnt2<=13;
                                    cnt1<=1;
                                    state<=state22;
                                end
                            else
                                begin
                                    cnt2<=cnt2-1;
                                    cnt1<=cnt1+1;
                                end
                        end
                    ////////////////////////////////////////
                    add_1 <= Lp[cnt1] + Sp[cnt2];
                    F1<= (&Lp[cnt1]  ||  &Sp[cnt2])? 1:0;
                end
                ////////////////////////////////////////////////
                state22:begin     /// O14 calculation
                    if(cnt == 2)
                        begin
                            cnt<=0;
                            O[14]<=O[14]^dec1;
                        end
                    else
                        cnt<=cnt+1;
                    /////////////////////////////////////////
                    if (cnt == 2)
                        begin
                            if (cnt2 == 6)
                                begin
                                    cnt2<=14;
                                    cnt1<=1;
                                    state<=state23;
                                end
                            else
                                begin
                                    cnt2<=cnt2-1;
                                    cnt1<=cnt1+1;
                                end
                        end
                    ////////////////////////////////////////
                    add_1 <= Lp[cnt1] + Sp[cnt2];
                    F1<= (&Lp[cnt1]  ||  &Sp[cnt2])? 1:0;
                end
                /////////////////////////////////////////////
                state23:begin     /// O15 calculation
                    if(cnt == 2)
                        begin
                            cnt<=0;
                            O[15]<=O[15]^dec1;
                        end
                    else
                        cnt<=cnt+1;
                    /////////////////////////////////////////
                    if (cnt == 2)
                        begin
                            if (cnt2 == 7)
                                begin
                                    cnt2<=15;
                                    cnt1<=1;
                                    state<=state24;
                                end
                            else
                                begin
                                    cnt2<=cnt2-1;
                                    cnt1<=cnt1+1;
                                end
                        end
                    ////////////////////////////////////////
                    add_1 <= Lp[cnt1] + Sp[cnt2];
                    F1<= (&Lp[cnt1]  ||  &Sp[cnt2])? 1:0;
                end
                //////////////////////////////////////////////
                state24:begin     /// O16 calculation
                    if(cnt == 2)
                        begin
                            cnt<=0;
                            O[16]<=O[16]^dec1;
                        end
                    else
                        cnt<=cnt+1;
                    /////////////////////////////////////////
                    if (cnt == 2)
                        begin
                            if (cnt2 == 8)
                                begin
                                    cnt2<=0;
                                    cnt1<=0;
                                    state<=state25;
                                end
                            else
                                begin
                                    cnt2<=cnt2-1;
                                    cnt1<=cnt1+1;
                                end
                        end
                    ////////////////////////////////////////
                    add_1 <= Lp[cnt1] + Sp[cnt2];
                    F1<= (&Lp[cnt1]  ||  &Sp[cnt2])? 1:0;
                end
                ////////////////////////////////////////////////
                state25:begin     //// getting power values of O2 : O16
                    if (cnt == 6)
                        begin
                            state<=state26;     
                            cnt<=0;
                            poly_ready<=1;	
                        end
                    else
                        cnt<=cnt+1;
                    ///////////////////////////////////////
                    case(cnt)
                    
                    0:begin
                        add_pow1<= O[2];
                        add_pow2<= O[3];
                        add_pow3<= O[4];
                    end
                    
                    1:begin
                        add_pow1<= O[5];
                        add_pow2<= O[6];
                        add_pow3<= O[7];
                    end
                    
                    2:begin
                        add_pow1<= O[8];
                        add_pow2<= O[9];
                        add_pow3<= O[10];
                        
                        O[2] <= pow1;
                        O[3]  <= pow2;
                        O[4] <= pow3;
                    end
                    
                    3:begin
                        add_pow1<= O[11];
                        add_pow2<= O[12];
                        add_pow3<= O[13];
                        
                        O[5] <= pow1;
                        O[6]  <= pow2;
                        O[7] <= pow3;
                    end
                    
                    4:begin
                        add_pow1<= O[14];
                        add_pow2<= O[15];
                        add_pow3<= O[16];
                        
                        O[8] <= pow1;
                        O[9]  <= pow2;
                        O[10] <= pow3;
                    end
                    
                    5:begin
                        O[11] <= pow1;
                        O[12]  <= pow2;
                        O[13] <= pow3;
                    end
                    
                    default:begin
                        O[14] <= pow1;
                        O[15]  <= pow2;
                        O[16] <= pow3;
                    end
                    
                    endcase
                    
                end
                /////////////////////////////////////////////////
                default:begin     /// state26   
                    poly_ready<=0;
                    state<=state1;
                end
                ///////////////////////////////////////////////
                endcase
            end
    end


endmodule 

module out_stage_ref
    /////  generate output bytes from pipeling memories
    (

    input clk, // input clock planned to be 56 Mhz
    input reset, // active high asynchronous reset

    // active high flag for one clock to indicate that the block should work
    input DONE, 

    output reg RE,  /// RE for input memories 

    output reg [7:0] RdAdd,

    input [7:0] In_byte,
    //////////////////////////////////////
    output reg [7:0] Out_byte,
    output reg CEO,
    output reg Valid_out,
    //////////////////////////////////////
    output reg out_done

    );

    reg CE;
    reg [2:0] cnt8;


    reg state;  //// 0 or 1

    reg F;  /// flag to control translation from state 0 to state1

    ////// CE generation///////////
    always@(posedge clk or posedge reset)
    begin
        if(reset)
            begin
                CE<=0;
                cnt8<=0;
                CEO<=0;
            end
        else
            begin
                cnt8<=cnt8+1;
                CEO <= CE;
                
                if(&cnt8)
                    CE<=1;
                else
                    CE<=0;
            end
    end
    //////////////////////////////////////////////////////////
    always@(posedge clk or posedge reset)
    begin
        if(reset)
            begin
                RE<=0;
                RdAdd<=0;
                out_done<=0;
                state<=0;
                Valid_out<=0;
                Out_byte<=0;
                F<=0;
            end
        else
            begin
                case(state)
                ////////////////////////////////////////////////
                1:begin  // operation is running
                    if (CE)
                            begin
                                if(RdAdd == 187)
                                    begin
                                        state<=0;
                                        out_done<=1;
                                    end
                                else	
                                    RdAdd<=RdAdd+1;
                                    
                                    Out_byte<=In_byte;
                                    Valid_out<=1;
                            end	
                end
                ///////////////////////////////////////////////
                default:begin    /// idle state
                    if(CE)
                        Valid_out<=0;
                    
                    
                    out_done<=0;
                    
                    if(DONE)
                        begin
                            F<=1;
                            RE<=~RE;
                            RdAdd<=0;
                        end
                    
                    if(F && CE)
                        begin
                            state<=1;
                            F<=0;
                        end
                end
                /////////////////////////////////////////////////////////////////////
                endcase
            end
    end

endmodule 

module RefModule 
    //////////// integration of decoder blocks
    (
    input clk, // input clock 
    input reset, // active high asynchronous reset
    input CE, // chip enable active high flag for one clock with every input byte (minimum spaceing 8 clocks)
    input [7:0] input_byte, // input byte
    
    output [7:0] Out_byte,   // output byte
    output CEO,  // chip enable for the next block will be active high for one clock , every 8 clks
    output Valid_out /// valid out for every output block (188 byte)
    );


    wire CEO_0;

    ///////////////////////////////////////assigns////////////////////////
    assign CEO = CEO_0 && Valid_out ;

    //////////////////////////////// input_syndromes/////////////////
    wire S_ready;  // active high flag for one clock to indicate that syndromes is ready 
    /// syndromes decimal values
    wire [7:0] s0,s1,s2,s3,s4,s5,s6,s7;   
    wire [7:0] s8,s9,s10,s11,s12,s13,s14,s15;   

    wire [7:0] In_mem_Read_byte;
    wire [7:0] In_mem_R_Add;
    wire  In_mem_RE;

    /////////////////////////////////////////////////////////////
    input_syndromes_ref input_syndromes_unit
    (
    .clk(clk), 
    .reset(reset), 
    .CE(CE),  // chip enable active high flag should be active for one clock with every input
    .input_byte(input_byte), // input byte

    //////////////////////////////////////
    .R_Add(In_mem_R_Add),
    .RE(In_mem_RE),
    .Read_byte(In_mem_Read_byte),

    /// syndromes 16 elements
    .S_Ready(S_ready),
    .s0(s0),.s1(s1),.s2(s2),.s3(s3),.s4(s4),.s5(s5),.s6(s6),.s7(s7),
    .s8(s8),.s9(s9),.s10(s10),.s11(s11),.s12(s12),.s13(s13),.s14(s14),.s15(s15)

    );

    /////////////////transport_in2out////////////////////////////////////
    wire WE_transport;
    wire [7:0]WrAdd_transport;

    wire transport_done;
    ////////////////////////////////////////////////////////////////
    transport_in2out_ref  transport_in2out_unit
    (

    .clk(clk), 
    .reset(reset), 

    .S_Ready(S_ready), 

    .RE(In_mem_RE),
    .RdAdd(In_mem_R_Add),

    .WE(WE_transport),  
    .WrAdd(WrAdd_transport),

    .Wr_done(transport_done)

    );


    ////////BM_lamda//////////////////////////////////////////////////////////
    wire  L_ready;  // active high flag for one clock to indicate that lamda polynomial is ready
    wire [7:0] L1,L2,L3,L4,L5,L6,L7,L8;   ///  lamda coeff values in decimal format 

    reg [7:0] pow1_BM_lamda,pow2_BM_lamda;    
    reg [7:0] dec1_BM_lamda;        

    wire  [7:0] add_pow1_BM_lamda,add_pow2_BM_lamda;  
    wire  [7:0] add_dec1_BM_lamda;    

    ///////////////////////////////////////////////////////////////////////////////////////////////////
    BM_lamda_ref   BM_lamda_unit
    (
    .clk(clk), 
    .reset(reset),

    .erasure_ready(1'b0),
    .erasure_cnt(4'b0),


    .Sm_ready(S_ready),
    .Sm1(s0),
    .Sm2(s1),
    .Sm3(s2),
    .Sm4(s3),
    .Sm5(s4),
    .Sm6(s5),
    .Sm7(s6),
    .Sm8(s7), 
    .Sm9(s8),
    .Sm10(s9),
    .Sm11(s10),
    .Sm12(s11),
    .Sm13(s12),
    .Sm14(s13),
    .Sm15(s14),
    .Sm16(s15),




    .add_pow1(add_pow1_BM_lamda),  
    .add_pow2(add_pow2_BM_lamda),  

    .add_dec1(add_dec1_BM_lamda),



    .pow1(pow1_BM_lamda),  
    .pow2(pow2_BM_lamda),  

    .dec1(dec1_BM_lamda),




    .L_ready(L_ready),
    .L1(L1),
    .L2(L2),
    .L3(L3),
    .L4(L4),
    .L5(L5),
    .L6(L6),
    .L7(L7),
    .L8(L8) 
    
    );

    ////////////lamda_roots////////////////////////////////////////////////////////////////
    wire roots_ready;
    wire [3:0] root_cnt;  //from 0 to 8
    wire [7:0] r1,r2,r3,r4,r5,r6,r7,r8; // output roots of lamda polynomial (decimal) up to 8 roots

    reg [7:0] pow1_lamda_roots;    
    reg [7:0] dec1_lamda_roots,dec2_lamda_roots,dec3_lamda_roots;        

    wire  [7:0] add_pow1_lamda_roots;  
    wire  [7:0] add_dec1_lamda_roots,add_dec2_lamda_roots,add_dec3_lamda_roots;    

    ////////////////////////////////////////////////////////////////////////////////////////
    lamda_roots_ref lamda_roots_unit
    (
    .CE(L_ready), 
    .clk(clk), 
    .reset(reset), 

    .Lc0(8'h01),   // always equals one 
    .Lc1(L1),
    .Lc2(L2),
    .Lc3(L3),
    .Lc4(L4),
    .Lc5(L5),
    .Lc6(L6),
    .Lc7(L7),
    .Lc8(L8), 

    .add_GF_ascending(add_pow1_lamda_roots),   
    .add_GF_dec0(add_dec1_lamda_roots),
    .add_GF_dec1(add_dec2_lamda_roots),
    .add_GF_dec2(add_dec3_lamda_roots),         

    .power(pow1_lamda_roots),  
    .decimal0(dec1_lamda_roots),
    .decimal1(dec2_lamda_roots),
    .decimal2(dec3_lamda_roots),

    .CEO(roots_ready), 
    .root_cnt(root_cnt), ///  up to 8
    .r1(r1),
    .r2(r2),
    .r3(r3),
    .r4(r4),
    .r5(r5),
    .r6(r6),
    .r7(r7),
    .r8(r8)
    );

    ///////////Omega_Phy//////////////////////////////////////////////////////////////////////
    wire  poly_ready ;  // active high flag for one clock to indicate that Phy and Omega polynomials are ready

    wire   [7:0] O1;    // decimal value of first coeff of Omega polynomial
    wire   [7:0] O2,O3,O4,O5,O6,O7,O8,O9,O10,O11,O12,O13,O14,O15,O16;  /// power values of omega polynomial coeff from 2:16

    wire   [7:0] P1;    // decimal value of first coeff of Phy polynomial
    wire   [7:0] P3,P5,P7;  /// power values of Phy polynomial coeff 

    reg [7:0] dec1_Omega_Phy;    
    reg [7:0] pow1_Omega_Phy,pow2_Omega_Phy,pow3_Omega_Phy;        

    wire  [7:0] add_dec1_Omega_Phy;  
    wire  [7:0] add_pow1_Omega_Phy,add_pow2_Omega_Phy,add_pow3_Omega_Phy;    


    ////////////////////////////////////////////////////////////////////////////////////
    Omega_Phy_ref   Omega_Phy_unit
    (
    .clk(clk), 
    .reset(reset), 


    .Sm_ready(S_ready),
    .Sm1(s0),
    .Sm2(s1),
    .Sm3(s2),
    .Sm4(s3),
    .Sm5(s4),
    .Sm6(s5),
    .Sm7(s6),
    .Sm8(s7), 
    .Sm9(s8),
    .Sm10(s9),
    .Sm11(s10),
    .Sm12(s11),
    .Sm13(s12),
    .Sm14(s13),
    .Sm15(s14),
    .Sm16(s15),





    .add_pow1(add_pow1_Omega_Phy),  
    .add_pow2(add_pow2_Omega_Phy),  
    .add_pow3(add_pow3_Omega_Phy),  

    .add_dec1(add_dec1_Omega_Phy),



    .pow1(pow1_Omega_Phy),  
    .pow2(pow2_Omega_Phy),  
    .pow3(pow3_Omega_Phy),  

    .dec1(dec1_Omega_Phy),




    .L_ready(L_ready),
    .L1(L1),
    .L2(L2),
    .L3(L3),
    .L4(L4),
    .L5(L5),
    .L6(L6),
    .L7(L7),
    .L8(L8) ,



    .poly_ready(poly_ready),
    .O1(O1), 
    .O2(O2), 
    .O3(O3), 
    .O4(O4), 
    .O5(O5), 
    .O6(O6), 
    .O7(O7), 
    .O8(O8), 
    .O9(O9), 
    .O10(O10), 
    .O11(O11), 
    .O12(O12), 
    .O13(O13), 
    .O14(O14), 
    .O15(O15), 
    .O16(O16), 

    .P1(P1), 
    .P3(P3), 
    .P5(P5), 
    .P7(P7)

    );

    //////////////////error_correction///////////////////////////////////////////
    wire RE_error_correction,WE_error_correction;    
    //// write and read enable for input block storage memory
    wire  [7:0] Address_error_correction;   //// address to input block storage memory
    wire  [7:0] correction_value;     //// corrected value  =  initial value xor  correction
    reg [7:0] initial_value;  //// input initial value

    wire  DONE;


    reg [7:0] pow1_error_correction,pow2_error_correction,pow3_error_correction,pow4_error_correction;    
    reg [7:0] dec1_error_correction,dec2_error_correction,dec3_error_correction,dec4_error_correction;        

    wire  [7:0] add_pow1_error_correction,add_pow2_error_correction,add_pow3_error_correction,add_pow4_error_correction;  
    wire  [7:0] add_dec1_error_correction,add_dec2_error_correction,add_dec3_error_correction,add_dec4_error_correction;    


    ////////////////////////////////////////////////////////////////////////////////
    error_correction_ref   error_correction_unit
    (
    .clk(clk), // .clock 
    .reset(reset), // active high asynchronous reset





    .add_pow1(add_pow1_error_correction),  
    .add_pow2(add_pow2_error_correction),  
    .add_pow3(add_pow3_error_correction),  
    .add_pow4(add_pow4_error_correction),  

    .add_dec1(add_dec1_error_correction),
    .add_dec2(add_dec2_error_correction),
    .add_dec3(add_dec3_error_correction),
    .add_dec4(add_dec4_error_correction),



    .pow1(pow1_error_correction),  
    .pow2(pow2_error_correction),  
    .pow3(pow3_error_correction),  
    .pow4(pow4_error_correction),  

    .dec1(dec1_error_correction),
    .dec2(dec2_error_correction),
    .dec3(dec3_error_correction),
    .dec4(dec4_error_correction),




    .roots_ready(roots_ready),
    .root_count(root_cnt),
    .r1(r1),
    .r2(r2),
    .r3(r3),
    .r4(r4),
    .r5(r5),
    .r6(r6),
    .r7(r7),
    .r8(r8) ,



    .poly_ready(poly_ready),
    .O1(O1), 
    .O2(O2), 
    .O3(O3), 
    .O4(O4), 
    .O5(O5), 
    .O6(O6), 
    .O7(O7), 
    .O8(O8), 
    .O9(O9), 
    .O10(O10), 
    .O11(O11), 
    .O12(O12), 
    .O13(O13), 
    .O14(O14), 
    .O15(O15), 
    .O16(O16), 

    .P1(P1), 
    .P3(P3), 
    .P5(P5), 
    .P7(P7),  

    .RE(RE_error_correction),
    .WE(WE_error_correction), 
    .Address(Address_error_correction), 
    .correction_value(correction_value), 
    .initial_value(initial_value),  

    .DONE(DONE)

    );

    ///////////////////////out_stage//////////////////////////////////////////////////////////
    wire RE_out_stage;
    wire [7:0] RdAdd_out_stage;
    reg [7:0] In_byte_out_stage;

    wire out_done;

    reg DONE_ext;   /// if DONE comes before out_stage is completed , extend DONE for the next block
    /////////////////////////////////////////////////////////////////////////////////////////////
    out_stage_ref   out_stage_unit
    (
    .clk(clk), 
    .reset(reset),

    .DONE(DONE || DONE_ext), 

    .RE(RE_out_stage),  

    .RdAdd(RdAdd_out_stage),

    .In_byte(In_byte_out_stage),
    
    .Out_byte(Out_byte),
    .CEO(CEO_0),
    .Valid_out(Valid_out),
    
    .out_done(out_done)
    );


    //////////////////out_memories//////////////////////////////////////////////////////////
    reg RE1,WE1,RE2,WE2;
    reg [7:0] R_Add1,W_Add1,R_Add2,W_Add2;
    wire [7:0] out_byte1,out_byte2;
    reg   [7:0] input_byte1,input_byte2;
    ////////////////////////////////////////////////////////////////////////////////////////////
    DP_RAM #(.num_words(188),.address_width(8),.data_width(8)) 
    mem_out_1 
    (
    .clk(clk),
    .we(WE1),
    .re(RE1),
    .address_read(R_Add1),
    .address_write(W_Add1),
    .data_in(input_byte1),
    .data_out(out_byte1)
    );

    DP_RAM #(.num_words(188),.address_width(8),.data_width(8))  
    mem_out_2
    (
    .clk(clk),
    .we(WE2),
    .re(RE2),
    .address_read(R_Add2),
    .address_write(W_Add2),
    .data_in(input_byte2),
    .data_out(out_byte2)
    );

    ///////////////////////////////////////////////////////////////////////////////////
    /////// GF Roms////////////////////////////////////////////////////////////////////

    wire [7:0] pow1,pow2,pow3,pow4;    /// output of power memories
    wire [7:0] dec1,dec2,dec3,dec4;        /// output of decimal memories

    reg  [7:0] add_pow1,add_pow2,add_pow3,add_pow4;  /// address to power memories
    reg  [7:0] add_dec1,add_dec2,add_dec3,add_dec4;    /// address to decimal memories

    ////// instant of GF_matrix_ascending_binary Rom////////////////////////////////////
    GF_matrix_ascending_binary   power_rom_instant1
    (
    .clk(clk),
    .re(1'b1),
    .address_read(add_pow1),
    .data_out(pow1)
    );
    /////// instant of GF_matrix_ascending_binary Rom////////////////////////////////////
    GF_matrix_ascending_binary   power_rom_instant2
    (
    .clk(clk),
    .re(1'b1),
    .address_read(add_pow2),
    .data_out(pow2)
    );
    ///////// instant of GF_matrix_ascending_binary Rom////////////////////////////////////
    GF_matrix_ascending_binary   power_rom_instant3
    (
    .clk(clk),
    .re(1'b1),
    .address_read(add_pow3),
    .data_out(pow3)
    );
    ////// instant of GF_matrix_ascending_binary Rom////////////////////////////////////
    GF_matrix_ascending_binary   power_rom_instant4
    (
    .clk(clk),
    .re(1'b1),
    .address_read(add_pow4),
    .data_out(pow4)
    );
    //////////GF_matrix_dec Rom //////////////////////////
    GF_matrix_dec rom_instant_1 
    (
    .clk(clk),
    .re(1'b1),
    .address_read(add_dec1),
    .data_out(dec1)
    );
    //////////GF_matrix_dec Rom //////////////////////////
    GF_matrix_dec rom_instant_2 
    (
    .clk(clk),
    .re(1'b1),
    .address_read(add_dec2),
    .data_out(dec2)
    );

    //////////GF_matrix_dec Rom //////////////////////////
    GF_matrix_dec rom_instant_3 
    (
    .clk(clk),
    .re(1'b1),
    .address_read(add_dec3),
    .data_out(dec3)
    );

    //////////GF_matrix_dec Rom //////////////////////////
    GF_matrix_dec rom_instant_4 
    (
    .clk(clk),
    .re(1'b1),
    .address_read(add_dec4),
    .data_out(dec4)
    );

    /////////////////////////////////////////////////////////////

    /////////////////////////////////////////////////////////////////////////
    ///////////////////////////////////////////////Main FSM//////////////////
    /////////////////////////////////////////////////////////////////////////

    reg S_flag,L_flag,R_flag,T_flag,out_flag;

    parameter state1  = 6'b000001;
    parameter state2  = 6'b000010;
    parameter state3  = 6'b000100;
    parameter state4  = 6'b001000;
    parameter state5  = 6'b010000;
    parameter state6  = 6'b100000;
    reg [5:0] state = state1;



    always@(posedge clk or posedge reset)
    begin
        if(reset)
            begin
                S_flag<=0;L_flag<=0;R_flag<=0;T_flag<=0;
                out_flag<=0;
                DONE_ext<=0;
                state<=state1;
            end
        else
            begin
            
                ///////////////////////////////////////////////////////////////////////////////////
                if(S_ready)
                    begin
                        T_flag<=1;
                    end			
                    
                if(transport_done)
                    begin
                        T_flag<=0;
                    end	
                ///////////////////////////////////////////////////////////////////////////////////
                if(DONE )
                    out_flag<=1;
                if(out_done && !DONE_ext && !DONE)
                    out_flag<=0;
                ///////////////////////////////////////////////////////////////////////////////////
                if(DONE  && out_flag && !out_done)  
                ///when error correction is done before out_stage end past operation, DONE_ext will be used
                    DONE_ext<=1;
                if(out_done)    
                ///// when out_stage is done no need for the DONE_ext flag as the out_stage block has allready use it
                    DONE_ext<=0;
                ///////////////////////////////////////////////////////////////////////////////////
                
                case(state)
                /////////////////////////////////////////////////////////////////////
                state1:begin
                    if(S_ready)
                        begin
                            S_flag<=1;
                            state<=state2;
                        end
                end
                ////////////////////////////////////////////////////////////
                state2:begin
                    if(L_ready)
                        begin
                            S_flag<=0;
                            L_flag<=1;
                            state<=state3;
                        end
                end
                ////////////////////////////////////////////////////////////
                state3:begin
                    if(roots_ready)
                        begin
                            L_flag<=0;
                            R_flag<=1;
                            state<=state4;
                        end
                end
                ////////////////////////////////////////////////////////////////
                default:begin   ///state4
                    if(DONE)
                        begin
                            R_flag<=0;
                            state<=state1;
                        end
                end
                /////////////////////////////////////////////////////////////
                
                endcase
            end
    end


    wire [2:0] control;

    assign control ={R_flag,L_flag,S_flag};


    ////////////////    GF memories switching ////////////////////
    always@(*)
    begin

        ////////////////////////////////////////////////////////////////////////////
        add_pow1<=0;
        add_pow2<=0;
        add_pow3<=0;
        add_pow4<=0;
        add_dec1<=0;
        add_dec2<=0;
        add_dec3<=0;
        add_dec4<=0;
        pow1_BM_lamda<=0;
        pow2_BM_lamda<=0;
        dec1_BM_lamda<=0;
        pow1_lamda_roots<=0;
        pow1_Omega_Phy<=0;
        pow2_Omega_Phy<=0;
        pow3_Omega_Phy<=0;
        dec1_lamda_roots<=0;
        dec2_lamda_roots<=0;
        dec3_lamda_roots<=0;
        dec1_Omega_Phy<=0;
        pow1_error_correction<=0;
        pow2_error_correction<=0;
        pow3_error_correction<=0;
        pow4_error_correction<=0;
        dec1_error_correction<=0;
        dec2_error_correction<=0;
        dec3_error_correction<=0;
        dec4_error_correction<=0;
        ////////////////////////////////////////////////////////////////////////////
        case (control)
        ///////////////////////////////////////////////////////////////////////////
            3'b001:begin
                add_pow1<=add_pow1_BM_lamda;
                add_pow2<=add_pow2_BM_lamda;
                
                add_dec1<=add_dec1_BM_lamda;
                
                pow1_BM_lamda<=pow1;
                pow2_BM_lamda<=pow2;
                
                dec1_BM_lamda<=dec1;
            end	
        /////////////////////////////////////////////////////////////////////////
            3'b010:begin
                add_pow1<=add_pow1_lamda_roots;
                add_pow2<=add_pow1_Omega_Phy;
                add_pow3<=add_pow2_Omega_Phy;
                add_pow4<=add_pow3_Omega_Phy;
                
                add_dec1<=add_dec1_lamda_roots;
                add_dec2<=add_dec2_lamda_roots;
                add_dec3<=add_dec3_lamda_roots;
                add_dec4<=add_dec1_Omega_Phy;
                
                pow1_lamda_roots<=pow1;
                pow1_Omega_Phy<=pow2;
                pow2_Omega_Phy<=pow3;
                pow3_Omega_Phy<=pow4;
                
                dec1_lamda_roots<=dec1;
                dec2_lamda_roots<=dec2;
                dec3_lamda_roots<=dec3;
                dec1_Omega_Phy<=dec4;
            end
        //////////////////////////////////////////////////////////////////////////////////////		
            3'b100:begin
                add_pow1<=add_pow1_error_correction;
                add_pow2<=add_pow2_error_correction;
                add_pow3<=add_pow3_error_correction;
                add_pow4<=add_pow4_error_correction;
                
                add_dec1<=add_dec1_error_correction;
                add_dec2<=add_dec2_error_correction;
                add_dec3<=add_dec3_error_correction;
                add_dec4<=add_dec4_error_correction;
                
                pow1_error_correction<=pow1;
                pow2_error_correction<=pow2;
                pow3_error_correction<=pow3;
                pow4_error_correction<=pow4;
                
                dec1_error_correction<=dec1;
                dec2_error_correction<=dec2;
                dec3_error_correction<=dec3;
                dec4_error_correction<=dec4;
                
            end	
        ////////////////////////////////////////////////////////////////////////////////
        endcase
    end
    ///////////////////////////////////////////////////////////////////////////////////////////////////



    ///////  Wrting control for out_memories ///////////////////////////////
    always@(posedge clk or posedge reset)
    begin
        if(reset)
            begin
                WE1<=0;
                WE2<=0;
                
                W_Add1<=0;
                W_Add2<=0;
                
                input_byte1<=0;
                input_byte2<=0;
            end
        
        else
            begin
            
                if(T_flag)
                    begin
    /////////////////////////////////////////////////transport_in2out
                            if (WE_transport )
                                begin
                                    WE1<=1;
                                    WE2<=0;
                                    
                                    W_Add1<=WrAdd_transport;
                                    W_Add2<=0;
                                    
                                    input_byte1<=In_mem_Read_byte;
                                    input_byte2<=0;
                                end
                            else
                                begin
                                    WE2<=1;
                                    WE1<=0;
                                    
                                    W_Add2<=WrAdd_transport;
                                    W_Add1<=0;
                                    
                                    input_byte2<=In_mem_Read_byte;
                                    input_byte1<=0;
                                end
                    end
                    
                else
                    begin
    //////////////////////////////////////////////////error correction
                            if (WE_transport )
                                begin
                                    WE1<=WE_error_correction;
                                    WE2<=0;
                                    
                                    W_Add1<=Address_error_correction;
                                    W_Add2<=0;
                                    
                                    input_byte1<=correction_value;
                                    input_byte2<=0;
                                end
                            else
                                begin
                                    WE2<=WE_error_correction;
                                    WE1<=0;
                                    
                                    W_Add2<=Address_error_correction;
                                    W_Add1<=0;
                                    
                                    input_byte2<=correction_value;
                                    input_byte1<=0;							
                                end
    ///////////////////////////////////////////////////////////////////////////////////////////////////////////
                    end	
            end				
    end

    /////////////////////////////////  Reading control for out_memories ///////////////////////////////
    always@(posedge clk or posedge reset)
    begin
        if(reset)
            begin
                RE1<=0;
                RE2<=0;
                R_Add1<=0;
                R_Add2<=0;
                initial_value<=0;
                In_byte_out_stage<=0;
            end
        else	
            begin
                if(R_flag)
                    begin
                        if (WE_transport )
                            begin
                                RE1<=RE_error_correction;
                                R_Add1<=Address_error_correction;
                                initial_value<=out_byte1;
                            end
                        else
                            begin
                                RE2<=RE_error_correction;
                                R_Add2<=Address_error_correction;
                                initial_value<=out_byte2;
                            end
                    end
                
                if(out_flag)
                    begin
                        if(RE_out_stage)
                            begin
                                RE1<=1;
                                R_Add1<=RdAdd_out_stage;
                                In_byte_out_stage<=out_byte1;
                            end
                        else
                            begin
                                RE2<=1;
                                R_Add2<=RdAdd_out_stage;
                                In_byte_out_stage<=out_byte2;
                            end
                    end
            end	
    end

endmodule

module transport_in2out_ref
    ///  transport input block from input pipeling memories to output pipeling memories
    (

    input clk, // input clock planned to be 56 Mhz
    input reset, // active high asynchronous reset

    // active high flag for one clock to indicate that the block should work
    input S_Ready, 

    output reg RE,WE,  /// RE for input memories , WE for output memories 

    output reg [7:0] RdAdd,WrAdd,

    output reg Wr_done

    );


    reg cnt;

    reg state;  //// 0 or 1



    always@(posedge clk or posedge reset)
    begin
        if(reset)
            begin
                WE<=0;
                RE<=0;
                RdAdd<=0;
                WrAdd<=0;
                Wr_done<=0;
                state<=0;
                cnt<=0;
            end
        else
            begin
                case(state)
                ////////////////////////////////////
                1:begin    //// operation is runing
                    cnt<=~cnt;
                    
                    if(cnt)
                        begin
                            WrAdd<=WrAdd+1;
                            if(WrAdd == 186)
                                begin
                                    state<=0;
                                    Wr_done<=1;
                                end
                        end
                    else
                        begin
                            RdAdd<=RdAdd-1;
                        end
                end
                ///////////////////////////////////////
                default:begin    //// idle state
                    Wr_done<=0;
                    if(S_Ready)
                        begin
                            state<=1;
                            RE<=~RE;
                            WE<=~WE;
                            RdAdd<= 204;
                            WrAdd<= 255;
                            cnt<=0;
                        end
                end
                ///////////////////////////////////
                endcase
            end
    end

endmodule 

module DP_RAM_ref (clk,we,re,address_read,address_write,data_in,data_out);

    parameter address_width=8;
    parameter data_width=8;
    parameter num_words=205;

    input clk,we,re;
    input [address_width-1:0] address_read,address_write;
    input [data_width-1:0] data_in;
    output [data_width-1:0] data_out;

    reg [data_width-1:0] data_out;
    reg [data_width-1:0] mem [0:num_words-1];

    integer		i;
        initial
        begin
            for (i=0;i<num_words;i=i+1)
                mem[i] = 0;
        end 

    always @ (posedge(clk))
    begin
        if (we==1'b1)
            begin
                mem[address_write]<= data_in;
            end
        if (re==1'b1)
            begin
                data_out<=mem[address_read];
            end
    end

endmodule

module GF_matrix_ascending_binary_ref (clk,re,address_read,data_out);
    parameter address_width=8;
    parameter data_width=8;
    parameter num_words=256;
    input clk,re;
    input [address_width-1:0] address_read;
    output [data_width-1:0] data_out;
    reg [data_width-1:0] data_out;
    reg [data_width-1:0] mem [0:num_words-1];
    initial
    begin
    mem[0]<= 'b11111111;
    mem[1]<= 'b00000000;
    mem[2]<= 'b00000001;
    mem[3]<= 'b00011001;
    mem[4]<= 'b00000010;
    mem[5]<= 'b00110010;
    mem[6]<= 'b00011010;
    mem[7]<= 'b11000110;
    mem[8]<= 'b00000011;
    mem[9]<= 'b11011111;
    mem[10]<= 'b00110011;
    mem[11]<= 'b11101110;
    mem[12]<= 'b00011011;
    mem[13]<= 'b01101000;
    mem[14]<= 'b11000111;
    mem[15]<= 'b01001011;
    mem[16]<= 'b00000100;
    mem[17]<= 'b01100100;
    mem[18]<= 'b11100000;
    mem[19]<= 'b00001110;
    mem[20]<= 'b00110100;
    mem[21]<= 'b10001101;
    mem[22]<= 'b11101111;
    mem[23]<= 'b10000001;
    mem[24]<= 'b00011100;
    mem[25]<= 'b11000001;
    mem[26]<= 'b01101001;
    mem[27]<= 'b11111000;
    mem[28]<= 'b11001000;
    mem[29]<= 'b00001000;
    mem[30]<= 'b01001100;
    mem[31]<= 'b01110001;
    mem[32]<= 'b00000101;
    mem[33]<= 'b10001010;
    mem[34]<= 'b01100101;
    mem[35]<= 'b00101111;
    mem[36]<= 'b11100001;
    mem[37]<= 'b00100100;
    mem[38]<= 'b00001111;
    mem[39]<= 'b00100001;
    mem[40]<= 'b00110101;
    mem[41]<= 'b10010011;
    mem[42]<= 'b10001110;
    mem[43]<= 'b11011010;
    mem[44]<= 'b11110000;
    mem[45]<= 'b00010010;
    mem[46]<= 'b10000010;
    mem[47]<= 'b01000101;
    mem[48]<= 'b00011101;
    mem[49]<= 'b10110101;
    mem[50]<= 'b11000010;
    mem[51]<= 'b01111101;
    mem[52]<= 'b01101010;
    mem[53]<= 'b00100111;
    mem[54]<= 'b11111001;
    mem[55]<= 'b10111001;
    mem[56]<= 'b11001001;
    mem[57]<= 'b10011010;
    mem[58]<= 'b00001001;
    mem[59]<= 'b01111000;
    mem[60]<= 'b01001101;
    mem[61]<= 'b11100100;
    mem[62]<= 'b01110010;
    mem[63]<= 'b10100110;
    mem[64]<= 'b00000110;
    mem[65]<= 'b10111111;
    mem[66]<= 'b10001011;
    mem[67]<= 'b01100010;
    mem[68]<= 'b01100110;
    mem[69]<= 'b11011101;
    mem[70]<= 'b00110000;
    mem[71]<= 'b11111101;
    mem[72]<= 'b11100010;
    mem[73]<= 'b10011000;
    mem[74]<= 'b00100101;
    mem[75]<= 'b10110011;
    mem[76]<= 'b00010000;
    mem[77]<= 'b10010001;
    mem[78]<= 'b00100010;
    mem[79]<= 'b10001000;
    mem[80]<= 'b00110110;
    mem[81]<= 'b11010000;
    mem[82]<= 'b10010100;
    mem[83]<= 'b11001110;
    mem[84]<= 'b10001111;
    mem[85]<= 'b10010110;
    mem[86]<= 'b11011011;
    mem[87]<= 'b10111101;
    mem[88]<= 'b11110001;
    mem[89]<= 'b11010010;
    mem[90]<= 'b00010011;
    mem[91]<= 'b01011100;
    mem[92]<= 'b10000011;
    mem[93]<= 'b00111000;
    mem[94]<= 'b01000110;
    mem[95]<= 'b01000000;
    mem[96]<= 'b00011110;
    mem[97]<= 'b01000010;
    mem[98]<= 'b10110110;
    mem[99]<= 'b10100011;
    mem[100]<= 'b11000011;
    mem[101]<= 'b01001000;
    mem[102]<= 'b01111110;
    mem[103]<= 'b01101110;
    mem[104]<= 'b01101011;
    mem[105]<= 'b00111010;
    mem[106]<= 'b00101000;
    mem[107]<= 'b01010100;
    mem[108]<= 'b11111010;
    mem[109]<= 'b10000101;
    mem[110]<= 'b10111010;
    mem[111]<= 'b00111101;
    mem[112]<= 'b11001010;
    mem[113]<= 'b01011110;
    mem[114]<= 'b10011011;
    mem[115]<= 'b10011111;
    mem[116]<= 'b00001010;
    mem[117]<= 'b00010101;
    mem[118]<= 'b01111001;
    mem[119]<= 'b00101011;
    mem[120]<= 'b01001110;
    mem[121]<= 'b11010100;
    mem[122]<= 'b11100101;
    mem[123]<= 'b10101100;
    mem[124]<= 'b01110011;
    mem[125]<= 'b11110011;
    mem[126]<= 'b10100111;
    mem[127]<= 'b01010111;
    mem[128]<= 'b00000111;
    mem[129]<= 'b01110000;
    mem[130]<= 'b11000000;
    mem[131]<= 'b11110111;
    mem[132]<= 'b10001100;
    mem[133]<= 'b10000000;
    mem[134]<= 'b01100011;
    mem[135]<= 'b00001101;
    mem[136]<= 'b01100111;
    mem[137]<= 'b01001010;
    mem[138]<= 'b11011110;
    mem[139]<= 'b11101101;
    mem[140]<= 'b00110001;
    mem[141]<= 'b11000101;
    mem[142]<= 'b11111110;
    mem[143]<= 'b00011000;
    mem[144]<= 'b11100011;
    mem[145]<= 'b10100101;
    mem[146]<= 'b10011001;
    mem[147]<= 'b01110111;
    mem[148]<= 'b00100110;
    mem[149]<= 'b10111000;
    mem[150]<= 'b10110100;
    mem[151]<= 'b01111100;
    mem[152]<= 'b00010001;
    mem[153]<= 'b01000100;
    mem[154]<= 'b10010010;
    mem[155]<= 'b11011001;
    mem[156]<= 'b00100011;
    mem[157]<= 'b00100000;
    mem[158]<= 'b10001001;
    mem[159]<= 'b00101110;
    mem[160]<= 'b00110111;
    mem[161]<= 'b00111111;
    mem[162]<= 'b11010001;
    mem[163]<= 'b01011011;
    mem[164]<= 'b10010101;
    mem[165]<= 'b10111100;
    mem[166]<= 'b11001111;
    mem[167]<= 'b11001101;
    mem[168]<= 'b10010000;
    mem[169]<= 'b10000111;
    mem[170]<= 'b10010111;
    mem[171]<= 'b10110010;
    mem[172]<= 'b11011100;
    mem[173]<= 'b11111100;
    mem[174]<= 'b10111110;
    mem[175]<= 'b01100001;
    mem[176]<= 'b11110010;
    mem[177]<= 'b01010110;
    mem[178]<= 'b11010011;
    mem[179]<= 'b10101011;
    mem[180]<= 'b00010100;
    mem[181]<= 'b00101010;
    mem[182]<= 'b01011101;
    mem[183]<= 'b10011110;
    mem[184]<= 'b10000100;
    mem[185]<= 'b00111100;
    mem[186]<= 'b00111001;
    mem[187]<= 'b01010011;
    mem[188]<= 'b01000111;
    mem[189]<= 'b01101101;
    mem[190]<= 'b01000001;
    mem[191]<= 'b10100010;
    mem[192]<= 'b00011111;
    mem[193]<= 'b00101101;
    mem[194]<= 'b01000011;
    mem[195]<= 'b11011000;
    mem[196]<= 'b10110111;
    mem[197]<= 'b01111011;
    mem[198]<= 'b10100100;
    mem[199]<= 'b01110110;
    mem[200]<= 'b11000100;
    mem[201]<= 'b00010111;
    mem[202]<= 'b01001001;
    mem[203]<= 'b11101100;
    mem[204]<= 'b01111111;
    mem[205]<= 'b00001100;
    mem[206]<= 'b01101111;
    mem[207]<= 'b11110110;
    mem[208]<= 'b01101100;
    mem[209]<= 'b10100001;
    mem[210]<= 'b00111011;
    mem[211]<= 'b01010010;
    mem[212]<= 'b00101001;
    mem[213]<= 'b10011101;
    mem[214]<= 'b01010101;
    mem[215]<= 'b10101010;
    mem[216]<= 'b11111011;
    mem[217]<= 'b01100000;
    mem[218]<= 'b10000110;
    mem[219]<= 'b10110001;
    mem[220]<= 'b10111011;
    mem[221]<= 'b11001100;
    mem[222]<= 'b00111110;
    mem[223]<= 'b01011010;
    mem[224]<= 'b11001011;
    mem[225]<= 'b01011001;
    mem[226]<= 'b01011111;
    mem[227]<= 'b10110000;
    mem[228]<= 'b10011100;
    mem[229]<= 'b10101001;
    mem[230]<= 'b10100000;
    mem[231]<= 'b01010001;
    mem[232]<= 'b00001011;
    mem[233]<= 'b11110101;
    mem[234]<= 'b00010110;
    mem[235]<= 'b11101011;
    mem[236]<= 'b01111010;
    mem[237]<= 'b01110101;
    mem[238]<= 'b00101100;
    mem[239]<= 'b11010111;
    mem[240]<= 'b01001111;
    mem[241]<= 'b10101110;
    mem[242]<= 'b11010101;
    mem[243]<= 'b11101001;
    mem[244]<= 'b11100110;
    mem[245]<= 'b11100111;
    mem[246]<= 'b10101101;
    mem[247]<= 'b11101000;
    mem[248]<= 'b01110100;
    mem[249]<= 'b11010110;
    mem[250]<= 'b11110100;
    mem[251]<= 'b11101010;
    mem[252]<= 'b10101000;
    mem[253]<= 'b01010000;
    mem[254]<= 'b01011000;
    mem[255]<= 'b10101111;
    end 
    always @ (posedge(clk))
    begin
        if (re==1'b1)
            begin
                data_out <= mem[address_read];
            end
    end
endmodule

module GF_matrix_dec_ref (clk,re,address_read,data_out);
    parameter address_width=8;
    parameter data_width=8;
    parameter num_words=256;
    input clk,re;
    input [address_width-1:0] address_read;
    output [data_width-1:0] data_out;
    reg [data_width-1:0] data_out;
    reg [data_width-1:0] mem [0:num_words-1];
    initial
    begin
    mem[0]<= 'b00000000;
    mem[1]<= 'b00000001;
    mem[2]<= 'b00000010;
    mem[3]<= 'b00000100;
    mem[4]<= 'b00001000;
    mem[5]<= 'b00010000;
    mem[6]<= 'b00100000;
    mem[7]<= 'b01000000;
    mem[8]<= 'b10000000;
    mem[9]<= 'b00011101;
    mem[10]<= 'b00111010;
    mem[11]<= 'b01110100;
    mem[12]<= 'b11101000;
    mem[13]<= 'b11001101;
    mem[14]<= 'b10000111;
    mem[15]<= 'b00010011;
    mem[16]<= 'b00100110;
    mem[17]<= 'b01001100;
    mem[18]<= 'b10011000;
    mem[19]<= 'b00101101;
    mem[20]<= 'b01011010;
    mem[21]<= 'b10110100;
    mem[22]<= 'b01110101;
    mem[23]<= 'b11101010;
    mem[24]<= 'b11001001;
    mem[25]<= 'b10001111;
    mem[26]<= 'b00000011;
    mem[27]<= 'b00000110;
    mem[28]<= 'b00001100;
    mem[29]<= 'b00011000;
    mem[30]<= 'b00110000;
    mem[31]<= 'b01100000;
    mem[32]<= 'b11000000;
    mem[33]<= 'b10011101;
    mem[34]<= 'b00100111;
    mem[35]<= 'b01001110;
    mem[36]<= 'b10011100;
    mem[37]<= 'b00100101;
    mem[38]<= 'b01001010;
    mem[39]<= 'b10010100;
    mem[40]<= 'b00110101;
    mem[41]<= 'b01101010;
    mem[42]<= 'b11010100;
    mem[43]<= 'b10110101;
    mem[44]<= 'b01110111;
    mem[45]<= 'b11101110;
    mem[46]<= 'b11000001;
    mem[47]<= 'b10011111;
    mem[48]<= 'b00100011;
    mem[49]<= 'b01000110;
    mem[50]<= 'b10001100;
    mem[51]<= 'b00000101;
    mem[52]<= 'b00001010;
    mem[53]<= 'b00010100;
    mem[54]<= 'b00101000;
    mem[55]<= 'b01010000;
    mem[56]<= 'b10100000;
    mem[57]<= 'b01011101;
    mem[58]<= 'b10111010;
    mem[59]<= 'b01101001;
    mem[60]<= 'b11010010;
    mem[61]<= 'b10111001;
    mem[62]<= 'b01101111;
    mem[63]<= 'b11011110;
    mem[64]<= 'b10100001;
    mem[65]<= 'b01011111;
    mem[66]<= 'b10111110;
    mem[67]<= 'b01100001;
    mem[68]<= 'b11000010;
    mem[69]<= 'b10011001;
    mem[70]<= 'b00101111;
    mem[71]<= 'b01011110;
    mem[72]<= 'b10111100;
    mem[73]<= 'b01100101;
    mem[74]<= 'b11001010;
    mem[75]<= 'b10001001;
    mem[76]<= 'b00001111;
    mem[77]<= 'b00011110;
    mem[78]<= 'b00111100;
    mem[79]<= 'b01111000;
    mem[80]<= 'b11110000;
    mem[81]<= 'b11111101;
    mem[82]<= 'b11100111;
    mem[83]<= 'b11010011;
    mem[84]<= 'b10111011;
    mem[85]<= 'b01101011;
    mem[86]<= 'b11010110;
    mem[87]<= 'b10110001;
    mem[88]<= 'b01111111;
    mem[89]<= 'b11111110;
    mem[90]<= 'b11100001;
    mem[91]<= 'b11011111;
    mem[92]<= 'b10100011;
    mem[93]<= 'b01011011;
    mem[94]<= 'b10110110;
    mem[95]<= 'b01110001;
    mem[96]<= 'b11100010;
    mem[97]<= 'b11011001;
    mem[98]<= 'b10101111;
    mem[99]<= 'b01000011;
    mem[100]<= 'b10000110;
    mem[101]<= 'b00010001;
    mem[102]<= 'b00100010;
    mem[103]<= 'b01000100;
    mem[104]<= 'b10001000;
    mem[105]<= 'b00001101;
    mem[106]<= 'b00011010;
    mem[107]<= 'b00110100;
    mem[108]<= 'b01101000;
    mem[109]<= 'b11010000;
    mem[110]<= 'b10111101;
    mem[111]<= 'b01100111;
    mem[112]<= 'b11001110;
    mem[113]<= 'b10000001;
    mem[114]<= 'b00011111;
    mem[115]<= 'b00111110;
    mem[116]<= 'b01111100;
    mem[117]<= 'b11111000;
    mem[118]<= 'b11101101;
    mem[119]<= 'b11000111;
    mem[120]<= 'b10010011;
    mem[121]<= 'b00111011;
    mem[122]<= 'b01110110;
    mem[123]<= 'b11101100;
    mem[124]<= 'b11000101;
    mem[125]<= 'b10010111;
    mem[126]<= 'b00110011;
    mem[127]<= 'b01100110;
    mem[128]<= 'b11001100;
    mem[129]<= 'b10000101;
    mem[130]<= 'b00010111;
    mem[131]<= 'b00101110;
    mem[132]<= 'b01011100;
    mem[133]<= 'b10111000;
    mem[134]<= 'b01101101;
    mem[135]<= 'b11011010;
    mem[136]<= 'b10101001;
    mem[137]<= 'b01001111;
    mem[138]<= 'b10011110;
    mem[139]<= 'b00100001;
    mem[140]<= 'b01000010;
    mem[141]<= 'b10000100;
    mem[142]<= 'b00010101;
    mem[143]<= 'b00101010;
    mem[144]<= 'b01010100;
    mem[145]<= 'b10101000;
    mem[146]<= 'b01001101;
    mem[147]<= 'b10011010;
    mem[148]<= 'b00101001;
    mem[149]<= 'b01010010;
    mem[150]<= 'b10100100;
    mem[151]<= 'b01010101;
    mem[152]<= 'b10101010;
    mem[153]<= 'b01001001;
    mem[154]<= 'b10010010;
    mem[155]<= 'b00111001;
    mem[156]<= 'b01110010;
    mem[157]<= 'b11100100;
    mem[158]<= 'b11010101;
    mem[159]<= 'b10110111;
    mem[160]<= 'b01110011;
    mem[161]<= 'b11100110;
    mem[162]<= 'b11010001;
    mem[163]<= 'b10111111;
    mem[164]<= 'b01100011;
    mem[165]<= 'b11000110;
    mem[166]<= 'b10010001;
    mem[167]<= 'b00111111;
    mem[168]<= 'b01111110;
    mem[169]<= 'b11111100;
    mem[170]<= 'b11100101;
    mem[171]<= 'b11010111;
    mem[172]<= 'b10110011;
    mem[173]<= 'b01111011;
    mem[174]<= 'b11110110;
    mem[175]<= 'b11110001;
    mem[176]<= 'b11111111;
    mem[177]<= 'b11100011;
    mem[178]<= 'b11011011;
    mem[179]<= 'b10101011;
    mem[180]<= 'b01001011;
    mem[181]<= 'b10010110;
    mem[182]<= 'b00110001;
    mem[183]<= 'b01100010;
    mem[184]<= 'b11000100;
    mem[185]<= 'b10010101;
    mem[186]<= 'b00110111;
    mem[187]<= 'b01101110;
    mem[188]<= 'b11011100;
    mem[189]<= 'b10100101;
    mem[190]<= 'b01010111;
    mem[191]<= 'b10101110;
    mem[192]<= 'b01000001;
    mem[193]<= 'b10000010;
    mem[194]<= 'b00011001;
    mem[195]<= 'b00110010;
    mem[196]<= 'b01100100;
    mem[197]<= 'b11001000;
    mem[198]<= 'b10001101;
    mem[199]<= 'b00000111;
    mem[200]<= 'b00001110;
    mem[201]<= 'b00011100;
    mem[202]<= 'b00111000;
    mem[203]<= 'b01110000;
    mem[204]<= 'b11100000;
    mem[205]<= 'b11011101;
    mem[206]<= 'b10100111;
    mem[207]<= 'b01010011;
    mem[208]<= 'b10100110;
    mem[209]<= 'b01010001;
    mem[210]<= 'b10100010;
    mem[211]<= 'b01011001;
    mem[212]<= 'b10110010;
    mem[213]<= 'b01111001;
    mem[214]<= 'b11110010;
    mem[215]<= 'b11111001;
    mem[216]<= 'b11101111;
    mem[217]<= 'b11000011;
    mem[218]<= 'b10011011;
    mem[219]<= 'b00101011;
    mem[220]<= 'b01010110;
    mem[221]<= 'b10101100;
    mem[222]<= 'b01000101;
    mem[223]<= 'b10001010;
    mem[224]<= 'b00001001;
    mem[225]<= 'b00010010;
    mem[226]<= 'b00100100;
    mem[227]<= 'b01001000;
    mem[228]<= 'b10010000;
    mem[229]<= 'b00111101;
    mem[230]<= 'b01111010;
    mem[231]<= 'b11110100;
    mem[232]<= 'b11110101;
    mem[233]<= 'b11110111;
    mem[234]<= 'b11110011;
    mem[235]<= 'b11111011;
    mem[236]<= 'b11101011;
    mem[237]<= 'b11001011;
    mem[238]<= 'b10001011;
    mem[239]<= 'b00001011;
    mem[240]<= 'b00010110;
    mem[241]<= 'b00101100;
    mem[242]<= 'b01011000;
    mem[243]<= 'b10110000;
    mem[244]<= 'b01111101;
    mem[245]<= 'b11111010;
    mem[246]<= 'b11101001;
    mem[247]<= 'b11001111;
    mem[248]<= 'b10000011;
    mem[249]<= 'b00011011;
    mem[250]<= 'b00110110;
    mem[251]<= 'b01101100;
    mem[252]<= 'b11011000;
    mem[253]<= 'b10101101;
    mem[254]<= 'b01000111;
    mem[255]<= 'b10001110;
    end 
    always @ (posedge(clk))
    begin
        if (re==1'b1)
            begin
                data_out <= mem[address_read];
            end
    end
endmodule