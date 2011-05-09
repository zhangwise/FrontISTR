//
//  FileReaderAssyModel.cpp
//
//              2009.04.08
//              2009.04.08
//              k.Takeda
#include "FileReaderAssyModel.h"
using namespace FileIO;
using namespace boost;
//  construct & destruct
//
CFileReaderAssyModel::CFileReaderAssyModel()
{
    ;
}

CFileReaderAssyModel::~CFileReaderAssyModel()
{
    ;
}

// アッセンブリーモデル => Meshの領域確保
//
bool CFileReaderAssyModel::Read(ifstream& ifs, string& sLine)
{
    
    uint nMeshID, numOfMesh, maxID, minID, nProp, mgLevel(0);// mgLevel=0 ::ファイル入力時のマルチグリッド==0
    vuint vMeshID;
    vuint vProp(0);//属性: 0:構造，1:流体
    istringstream iss;

    // MeshIDデータ for AssyModel
    if(TagCheck(sLine, FileBlockName::StartAssyModel()) ){
        //mpLogger->Info(Utility::LoggerMode::MWDebug, "FileReaderAssyModel", sLine);

        //debug
        cout << "FileReaderAssyModel::Read" << endl;

        // メッシュ数,MaxID,MinID
        //
        sLine = getLineSt(ifs);
        iss.clear();
        iss.str(sLine.c_str());
        iss >> numOfMesh >> maxID >> minID;
        
        // setup to BucketMesh in AssyModel
        mpFactory->setupBucketMesh(mgLevel, maxID, minID);
        
        // MeshID の連続データ
        //
        while(!ifs.eof()){
            sLine = getLineSt(ifs);
            if(TagCheck(sLine, FileBlockName::EndAssyModel()) ) break;

            iss.clear();
            iss.str(sLine.c_str());

            //// 単純なRead
            //iss >> nMeshID;
            //vMeshID.push_back(nMeshID);

            // boost  トークン分割
            // ----
            char_separator<char> sep(" \t\n");
            tokenizer< char_separator<char> > tokens(sLine, sep);

            uint nCount(0);
            typedef tokenizer< char_separator<char> >::iterator Iter;
            for(Iter it=tokens.begin(); it != tokens.end(); ++it){
                string str = *it;
                if(nCount==0){ nMeshID = atoi(str.c_str()); vMeshID.push_back(nMeshID);}
                if(nCount==1){ nProp   = atoi(str.c_str()); vProp.push_back(nProp);    }//入力ファイルにnPropが無ければvPropに値は入らない.
                nCount++;
            };

            
////            vstring vToken;
////            Split(sLine, ' ', vToken);
////            uint nNumOfToken = vToken.size();
////            cout << "vToken.size() = " << vToken.size() << endl;
////            if(nNumOfToken==1){
////
////                nMeshID = atoi(vToken[0].c_str());
////                vMeshID.push_back(nMeshID);
////            }
////            if(nNumOfToken==2){
////                nMeshID = atoi(vToken[0].c_str());
////                nProp   = atoi(vToken[1].c_str());
////                vMeshID.push_back(nMeshID);
////                vProp.push_back(nProp);
////            }
        };
        // Meshの領域確保
        //
        mpFactory->reserveMesh(mgLevel, numOfMesh);//ファイル読み込みなので,mgLevel=0

        // Meshの生成 for AssyModel(at mgLevel=0)
        //
        uint imesh, nNumOfMesh=vMeshID.size();
        if(vProp.size()==vMeshID.size()){
            for(imesh=0; imesh < nNumOfMesh; imesh++){
                mpFactory->GeneMesh(mgLevel, vMeshID[imesh], imesh, vProp[imesh]);
            };
        }else{
            // vPropに値がセットされていない.(入力ファイルに定義されていなかった)
            for(imesh=0; imesh < nNumOfMesh; imesh++){
                mpFactory->GeneMesh(mgLevel, vMeshID[imesh], imesh, nProp);// nPropは初期値0:構造
            };
        }

        return true;
    }else{
        return false;
    }
}
